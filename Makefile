TARGET = test.elf
BINARY = $(TARGET:.elf=.bin)

CROSS = arc-elf32-

CC = $(CROSS)gcc
CXX = $(CROSS)g++
OC = $(CROSS)objcopy
SZ = $(CROSS)size
RM = rm -rf
UPLOADER = arduino101load

TTY_PORT = /dev/cu.usbmodemF*

LIBS = CurieBLE CurieIMU CurieTimerOne Wire

ARCH_FLAGS = -mcpu=quarkse_em -mlittle-endian

INCLUDES += $(foreach lib,$(wildcard $(LIBDIR)/*),-I./$(lib))
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

SRCDIR = src
LIBDIR = lib
OBJDIR = obj
VPATH = $(SRCDIR) $(LIBDIR) $(ARC_LIBRARY)

TAGS = .tags

C_SRC = $(shell find $(SRCDIR) -name '*.c')
CXX_SRC = $(shell find $(SRCDIR) -name '*.cpp')
LIB_C_SRC = $(shell find $(LIBDIR) -name '*.c' -not -path '*/examples/*')
LIB_CXX_SRC = $(shell find $(LIBDIR) -name '*.cpp' -not -path '*/examples/*')
CORE_C_SRC = $(shell find $(ARC_LIBRARY)/cores -name '*.c')
CORE_CXX_SRC += $(shell find $(ARC_LIBRARY)/cores -name '*.cpp')
CORE_CXX_SRC += $(shell find $(ARC_LIBRARY)/variants -name '*.cpp')

ifneq ($(LIBS),)
	FIND_C = $(shell find $(ARC_LIBRARY)/libraries/$(LIBNAME)/src -name '*.c')
	FIND_CXX = $(shell find $(ARC_LIBRARY)/libraries/$(LIBNAME)/src -name '*.cpp')
	INCLUDES += $(foreach LIBNAME,$(LIBS),-I$(ARC_LIBRARY)/libraries/$(LIBNAME)/src)
	CORE_C_SRC += $(foreach LIBNAME,$(LIBS),$(FIND_C))
	CORE_CXX_SRC += $(foreach LIBNAME,$(LIBS),$(FIND_CXX))
endif

OBJS += $(patsubst $(SRCDIR)/%.c, $(OBJDIR)/%.o, $(C_SRC))
OBJS += $(patsubst $(SRCDIR)/%.cpp, $(OBJDIR)/%.o, $(CXX_SRC))
OBJS += $(patsubst $(LIBDIR)/%.c, $(OBJDIR)/%.o, $(LIB_C_SRC))
OBJS += $(patsubst $(LIBDIR)/%.cpp, $(OBJDIR)/%.o, $(LIB_CXX_SRC))
OBJS += $(patsubst $(ARC_LIBRARY)/%.c, $(OBJDIR)/%.o, $(CORE_C_SRC))
OBJS += $(patsubst $(ARC_LIBRARY)/%.cpp, $(OBJDIR)/%.o, $(CORE_CXX_SRC))

OUTDIRS = $(sort $(dir $(OBJS)))

SIZE = $(OBJDIR)/.size

.PHONY: all clean upload

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
	@ctags -R --c-kinds=+xp --extra=+q --fields=+KSn -f $@ \
		--exclude='*.c' --exclude='*.cpp' \
		$(SRCDIR) \
		$(LIBDIR) \
		$(ARC_LIBRARY)/cores \
		$(ARC_LIBRARY)/variants \
		$(ARC_LIBRARY)/system \
		$(ARC_TOOLS)/arc-elf32/include \
		$(foreach LIBNAME,$(LIBS),$(ARC_LIBRARY)/libraries/$(LIBNAME)/src)

# Rules
$(OBJDIR)/%.o: %.c
	@echo "Compiling $(notdir $<)"
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR)/%.o: %.cpp
	@echo "Compiling $(notdir $<)"
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Misc
clean:
	@echo "make: Cleaning all targets"
	@$(RM) $(OBJDIR) $(TARGET) $(BINARY) $(TAGS)

upload: $(BINARY)
	@echo "Resetting the device $(TTY_PORT) for upload..."
	-@picocom -b 1200 $(TTY_PORT) > /dev/null &
	@$(UPLOADER) $(ARC_UPLOADER)/x86/bin $< $(TTY_PORT) verbose
