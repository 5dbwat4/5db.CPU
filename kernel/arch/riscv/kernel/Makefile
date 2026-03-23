RISCV_PREFIX ?= riscv64-linux-gnu-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -march=rv64ia_zicsr_zifencei -mabi=lp64 -mcmodel=medany -fvisibility=hidden -fno-builtin -nostdlib -nostartfiles -DNOBRANCH
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump -Mno-aliases -D
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy -O binary
RISCV_LD      ?= $(RISCV_PREFIX)ld

# 源文件
SRC_C = $(wildcard ./*.c)
SRC_S = $(wildcard ./*.S)

# 头文件路径
INCLUDE_FLAG = -I ../../include -I ../include -I ./include -I ../../../include

# 目标文件
SRC_OBJ = $(patsubst %.c,%.o, $(SRC_C)) $(patsubst %.S,%.o, $(SRC_S))

# 输出文件
TARGET = vmlinux
TARGET_ELF := $(TARGET).elf
TARGET_ASM := $(TARGET).asm
TARGET_BIN := $(TARGET).bin

.PHONY: all clean

# all: $(TARGET_BIN)
# 	@echo "Building with CFLAGS: $(CFLAGS)"

# $(TARGET_BIN): $(TARGET_ELF)
# 	$(RISCV_OBJCOPY) $(TARGET_ELF) $(TARGET_BIN)

# $(TARGET_ASM): $(TARGET_ELF)
# 	$(RISCV_OBJDUMP) $(TARGET_ELF) > $(TARGET_ASM)

# $(TARGET_ELF): $(SRC_OBJ)
# 	$(RISCV_LD) -T vmlinux.lds $(SRC_OBJ) -o $(TARGET_ELF)

all: $(SRC_OBJ)

%.o: %.S
	$(RISCV_GCC) $(CFLAGS) $(INCLUDE_FLAG) -c $< -o $@

%.o: %.c
	$(RISCV_GCC) $(CFLAGS) $(INCLUDE_FLAG) -c $< -o $@

clean:
	rm -rf $(SRC_OBJ) $(TARGET_ELF) $(TARGET_ASM) $(TARGET_BIN) 2> /dev/null