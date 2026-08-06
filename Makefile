.PHONY: test shellcheck

test:
	./tests/host/imager_test.sh
	python3 -m unittest tests/test_network_portal.py
	python3 -m unittest tests/test_imager_app.py
	python3 -m unittest discover -s device/agent/tests -v
	python3 -m py_compile host/imager_app.py device/network/network_portal.py device/agent/setup.py
	@for file in $$(find host device -type f \( -name '*.sh' -o -name cdmx-network \)); do bash -n "$$file"; done

shellcheck:
	shellcheck -x --exclude=SC1091 host/*.sh host/lib/*.sh device/*.sh device/*/*.sh device/network/cdmx-network tests/host/*.sh
