.PHONY: test

test:
	shellspec -c . --quick

docker-test:
	docker build -f Dockerfile.test -t trivy-action:test .
	docker run --rm trivy-action:test --quick
