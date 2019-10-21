PYICU_VERSION = 2.3.1
ICU_VERSION = 65_1

all: manylinux1_x86_64 manylinux1_i686 macosx

clean:
	rm -rf dist .cache .venv

manylinux1_i686:
	docker run --rm -v $(PWD):/build \
		--env PYICU_VERSION=$(PYICU_VERSION) --env ICU_VERSION=$(ICU_VERSION) \
		quay.io/pypa/manylinux1_i686 linux32 /build/scripts/build-manylinux.sh

manylinux1_x86_64:
	docker run --rm -v $(PWD):/build \
		--env PYICU_VERSION=$(PYICU_VERSION) --env ICU_VERSION=$(ICU_VERSION) \
		quay.io/pypa/manylinux1_x86_64 /build/scripts/build-manylinux.sh

macosx:
	PYICU_VERSION=$(PYICU_VERSION) ICU_VERSION=$(ICU_VERSION) scripts/build-macosx.sh

release-test:
	twine upload --repository-url https://test.pypi.org/legacy/ dist/*

release:
	twine upload dist/*

.PHONY: all clean manylinux1_i686 manylinux1_x86_64 macosx release-test release
