AS       := clang
ARCH     := arm64
ASFLAGS  := -arch $(ARCH)
TARGET   := demo
SRC      := demo.s

HOSTARCH := $(shell uname -m)

all: $(TARGET)

$(TARGET): $(SRC) Makefile
ifneq ($(HOSTARCH),arm64)
	$(error $(TARGET) is aarch64 only, host reports $(HOSTARCH))
endif
	$(AS) $(ASFLAGS) $(SRC) -o $@

run: $(TARGET)
	./$(TARGET) -fps

clean:
	rm -f $(TARGET)

.PHONY: all run clean
