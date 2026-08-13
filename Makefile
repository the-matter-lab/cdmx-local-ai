.PHONY: test shellcheck

test:
	python3 -m unittest discover -s device/agent/tests -v
	python3 -m py_compile device/agent/setup.py
	python3 -m py_compile device/agent/workspace/tools/cdmx_hardware.py
	bash -n device/agent/install-agent.sh

shellcheck:
	shellcheck device/agent/install-agent.sh
