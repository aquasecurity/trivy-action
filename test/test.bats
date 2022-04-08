#!/usr/bin/env bats

@test "trivy image" {
  # trivy image --severity CRITICAL -o image.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-b table' '-h image.test' '-g CRITICAL'
  result="$(diff ./test/data/image.test image.test)"
  [ "$result" == '' ]
}

@test "trivy image sarif report" {
  # trivy image --severity CRITICAL -f sarif -o image-sarif.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-b sarif' '-h image-sarif.test' '-g CRITICAL'
  result="$(diff ./test/data/image-sarif.test image-sarif.test)"
  [ "$result" == '' ]
}

@test "trivy config" {
  # trivy conf -o config.test .
  ./entrypoint.sh '-a config' '-j .' '-b table' '-h config.test'
  result="$(diff ./test/data/config.test config.test)"
  [ "$result" == '' ]
}

@test "trivy rootfs" {
  # trivy rootfs -o rootfs.test -f json .
  ./entrypoint.sh '-a rootfs' '-j .' '-b json' '-h rootfs.test'
  result="$(diff ./test/data/rootfs.test rootfs.test)"
  [ "$result" == '' ]
}

@test "trivy fs" {
  # trivy fs -f json -o fs.test .
  ./entrypoint.sh '-a fs' '-j .' '-b json' '-h fs.test'
  result="$(diff ./test/data/fs.test fs.test)"
  [ "$result" == '' ]
}

@test "trivy repo" {
  # trivy repo -f json -o repo.test --severity CRITICAL https://github.com/aquasecurity/trivy-action/
  ./entrypoint.sh '-b json' '-h repo.test' '-g CRITICAL' '-a repo' '-j https://github.com/aquasecurity/trivy-action/'
  result="$(diff ./test/data/repo.test repo.test)"
  [ "$result" == '' ]
}