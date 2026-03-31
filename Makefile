rwildcard = $(foreach d,$(wildcard $1/*),$(call rwildcard,$d,$2)) \
            $(filter $(subst *,%,$2),$1)

all: build
.PHONY: all

.PHONY: FORCE
FORCE:

###############################################################################

BUILD_DIR := builddir
OUT_DIR := $(BUILD_DIR)/out

export LD_LIBRARY_PATH := $(realpath $(OUT_DIR)):$(LD_LIBRARY_PATH)

# Compiler
LDC2 = ldc2
LDC2_SRC ?= ldc2-src

SRCS := $(call rwildcard,source,*.d) \
	$(call rwildcard,libdparse/src,*.d) \
	$(call rwildcard,$(LDC2_SRC)/runtime/phobos/std,*.d)

OBJS := $(patsubst %.d,$(BUILD_DIR)/%.o,$(SRCS))
DEPS := $(OBJS:.o=.d)

# Target
TARGET = $(OUT_DIR)/libldclint.so

# Flags
SRC_DFLAGS := \
	 -Isource -Ilibdparse/src \
	 --relocation-model=pic \
	 --fvisibility=hidden \
	 --conf= --defaultlib= \
	 --d-version=IN_LLVM \
	 -I$(LDC2_SRC) \
	 -J$(LDC2_SRC)/dmd/res \
	 -I$(LDC2_SRC)/runtime/druntime/src \
	 -I$(LDC2_SRC)/runtime/phobos

DEBUG ?= 0

ifeq ($(DEBUG),1)
DEBUG_DFLAGS := -g -O0 -debug
else
DEBUG_DFLAGS := -O3 -release
endif

DFLAGS ?=

$(BUILD_DIR)/.dyn.dflags: FORCE
	@mkdir -p $(dir $@)
	@echo "$(DEBUG_DFLAGS) $(DFLAGS)" | cmp -s - $@ || (echo "$(DEBUG_DFLAGS) $(DFLAGS)" > $@)

DYN_FLAGS_DEP := $(BUILD_DIR)/.dyn.dflags

build: $(TARGET)
.PHONY: build

clean:
	rm -rf $(BUILD_DIR)

.PHONY: clean

###############################################################################

$(TARGET): $(OBJS)
	@echo " LINK " $(notdir $<)
	@$(LDC2) $(SRC_DFLAGS) $(DFLAGS) --shared $(OBJS) -of=$@
	@if [ "$(DEBUG)" = "0" ]; then \
		echo " STRIP " $(notdir $@); \
		strip --strip-all --keep-symbol=runSemanticAnalysis $@ ; \
	fi

$(BUILD_DIR)/%.o: %.d
	@echo " D " $(notdir $<)
	@mkdir -p $(dir $@)
	@$(LDC2) $(SRC_DFLAGS) $(DFLAGS) -makedeps=$(patsubst %.o,%.d,$@) -of=$@ -c $<

$(OBJS): Makefile $(DYN_FLAGS_DEP)
-include $(DEPS)

###############################################################################

VENV_DIR := $(BUILD_DIR)/.venv
PYTHON := $(VENV_DIR)/bin/python3

$(VENV_DIR)/bin/activate: requirements.txt
	@echo " VENV " $(notdir $<)
	@test -d $(VENV_DIR) || python3 -m venv $(VENV_DIR)
	@$(PYTHON) -m pip install -r $<

TESTS_DIR := tests
TESTS := $(call rwildcard,$(TESTS_DIR),*.d)
TESTS_OUTS := $(patsubst %.d,$(BUILD_DIR)/%.out.txt,$(TESTS))

LIT := $(VENV_DIR)/bin/lit


# FIXME: .lit_test_times.txt is not atomically updated
#
#test: $(TESTS_OUTS)
#$(TESTS_OUTS): $(TARGET) $(VENV_DIR)/bin/activate
#$(BUILD_DIR)/tests/%.out.txt: tests/%.d
#	@echo " TEST " $(notdir $<)
#	@mkdir -p $(dir $@)
#	@($(LIT) -sv --no-progress-bar $< 2>&1 > $@) || (cat $@ && rm -f $@)

test: $(TARGET) $(VENV_DIR)/bin/activate $(TESTS)
	@echo " TESTS "
	@$(LIT) -v tests

.PHONY: test

###############################################################################
