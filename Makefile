EMACS_TAG ?= emacs-30.1
EMACS_DIR := emacs
EMACS     := $(EMACS_DIR)/src/emacs

.PHONY: setup build repl test demo patch clean

## Clone + configure + build the pinned Emacs (first time; slow)
setup:
	scripts/setup-emacs.sh $(EMACS_TAG)

## Incremental rebuild after editing bytecode.c / alloc.c (fast)
build:
	$(MAKE) -C $(EMACS_DIR)

## Interactive patched Emacs with our lisp on the load path
repl:
	$(EMACS) -Q -L lisp -l bytecode-trace

## Run the ERT suite in batch mode
test:
	$(EMACS) -Q -batch -L lisp -L test -l bytecode-trace-tests \
	  -f ert-run-tests-batch-and-exit

## Run the lambda-calculus experiments in batch mode
demo:
	$(EMACS) -Q -batch -L lisp -L demo -l experiments \
	  -f bct-run-all-experiments

## Export the Emacs-tree changes as a reviewable patch
patch:
	cd $(EMACS_DIR) && git diff > ../patches/bytecode-tracing.patch
	@echo "wrote patches/bytecode-tracing.patch"

clean:
	rm -f lisp/*.elc demo/*.elc test/*.elc
