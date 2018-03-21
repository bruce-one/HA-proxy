.SILENT :
.PHONY : test-alpine test

update-dependencies:
	test/requirements/build.sh

test-alpine: update-dependencies
	docker build -f Dockerfile -t Max-Sum/haproxy-proxy:test .
	test/pytest.sh

test: test-alpine
