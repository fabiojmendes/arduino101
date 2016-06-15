TARGET = test.elf
BINARY = $(TARGET:.elf=.bin)

CROSS = arc-elf32-

CC = $(CROSS)gcc
CXX = $(CROSS)g++
OC = $(CROSS)objcopy
SZ = $(CROSS)size
RM = rm -rf
UPLOADER = arduino101load

SRCDIR = src
OBJDIR = obj
VPATH = $(SRCDIR) $(ARC_LIBRARY)

TAGS = .tags

C_SRC = $(shell find $(SRCDIR) -name '*.c')
CXX_SRC = $(shell find $(SRCDIR) -name '*.cpp')
CORE_C_SRC = $(shell find $(ARC_LIBRARY)/cores -name '*.c')
CORE_CXX_SRC += $(shell find $(ARC_LIBRARY)/cores -name '*.cpp')
CORE_CXX_SRC += $(shell find $(ARC_LIBRARY)/variants -name '*.cpp')

OBJS += $(patsubst $(SRCDIR)/%.c, $(OBJDIR)/%.o, $(C_SRC))
OBJS += $(patsubst $(SRCDIR)/%.cpp, $(OBJDIR)/%.o, $(CXX_SRC))
OBJS += $(patsubst $(ARC_LIBRARY)/%.c, $(OBJDIR)/%.o, $(CORE_C_SRC))
OBJS += $(patsubst $(ARC_LIBRARY)/%.cpp, $(OBJDIR)/%.o, $(CORE_CXX_SRC))
OUTDIRS = $(sort $(dir $(OBJS)))

SIZE = $(OBJDIR)/.size

ARCH_FLAGS = -mcpu=quarkse_em -mlittle-endian

INCLUDES += -I$(ARC_LIBRARY)/system/libarc32_arduino101/common
INCLUDES += -I$(ARC_LIBRARY)/system/libarc32_arduino101/drivers
INCLUDES += -I$(ARC_LIBRARY)/system/libarc32_arduino101/bootcode
INCLUDES += -I$(ARC_LIBRARY)/system/libarc32_arduino101/framework/include
INCLUDES += -I$(ARC_LIBRARY)/cores/arduino
INCLUDES += -I$(ARC_LIBRARY)/variants/arduino_101

DEFINES += -D__ARDUINO_ARC__ -DF_CPU=32000000L -DARDUINO=10609
DEFINES += -DARDUINO_ARC32_TOOLS -DARDUINO_ARCH_ARC32 -D__CPU_ARC__
DEFINES += -DCLOCK_SPEED=32 -DCFW_MULTI_CPU_SUPPORT -DHAS_SHARED_MEM
DEFINES += -DCONFIG_SOC_GPIO_32 -DCONFIG_SOC_GPIO_AON -DINFRA_MULTI_CPU_SUPPORT

COMMON_FLAGS += -Wall -Wno-unused-but-set-variable -Wno-main -Os -g
COMMON_FLAGS += -fno-reorder-functions -fno-asynchronous-unwind-tables
COMMON_FLAGS += -fno-omit-frame-pointer -fno-defer-pop -ffreestanding
COMMON_FLAGS += -fno-stack-protector -mno-sdata -ffunction-sections
COMMON_FLAGS += -fdata-sections -fsigned-char -MMD

CFLAGS  = $(INCLUDES) $(DEFINES) $(COMMON_FLAGS) -std=gnu11
CXXFLAGS  = $(INCLUDES) $(DEFINES) $(COMMON_FLAGS) -std=c++11 -fno-rtti -fno-exceptions

LDFLAGS += -nostartfiles -nodefaultlibs -nostdlib -static -Wl,-X -Wl,-N
LDFLAGS += -Wl,-mcpu=quarkse_em -Wl,-marcelf -Wl,--gc-sections
LDFLAGS += -T$(ARC_LIBRARY)/variants/arduino_101/linker_scripts/flash.ld
LDFLAGS += -L$(ARC_LIBRARY)/variants/arduino_101
LDFLAGS += -Wl,--whole-archive -larc32drv_arduino101 -Wl,--no-whole-archive
LDFLAGS += -Wl,--start-group

LDLIBS = -larc32drv_arduino101 -lnsim -lc -lm -lgcc

.PHONY = all

all: $(TARGET) $(TAGS) $(SIZE) $(BINARY) $(TAGS)

$(BINARY): $(TARGET)
	@echo "Copying $(notdir $@)"
	@$(OC) -S -O binary $< $@
	@echo
	@echo "-----------------------------"
	@echo "-- make: BUILD SUCCESSFUL! --"
	@echo "-----------------------------"

$(TARGET): $(OBJS)
	@echo "Linking $(notdir $@)"
	@$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(OBJS): Makefile | $(OUTDIRS)

$(OUTDIRS):
	@echo "make: Creating output directories"
	@mkdir -p $(OUTDIRS)

$(SIZE): $(TARGET)
	@$(SZ) $? | tee $@

$(TAGS): $(OBJS)
	@echo "Generating $@"
	@ctags -R --c-kinds=+xp --extra=+q --fields=+KSn --languages=c,c++ -f $@ \
		$(SRCDIR) \
		$(ARC_LIBRARY)/cores \
		$(ARC_LIBRARY)/variants \
		$(ARC_LIBRARY)/system

# Rules
$(OBJDIR)/%.o: %.c
	@echo "Compiling $(notdir $<)"
	@$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.cpp
	@echo "Compiling $(notdir $<)"
	@$(CXX) $(CXXFLAGS) -c $< -o $@

# Misc
clean:
	@echo "make: Cleaning all targets"
	@$(RM) $(OBJDIR) $(TARGET) $(BINARY) $(TAGS)

upload: $(BINARY)
	@echo "Resetting the device for upload..."
	-@picocom -b 1200 /dev/cu.usbmodemFA131 > /dev/null &
	@$(UPLOADER) $(ARC_UPLOADER)/x86/bin $< /dev/cu.usbmodemFA131 verbose
