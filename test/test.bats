#!/usr/bin/env bats

@test "trivy image" {
  # trivy image --severity CRITICAL -o image.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-b table' '-h test' '-g CRITICAL'
  result="$(diff ./test/data/image.test knqyf263-vuln-image:1.2.3-test)"
  [ "$result" == '' ]
}

@test "trivy multiple images" {
  # trivy image --severity CRITICAL -o image.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3,alpine:3.15.4' '-b table' '-h test' '-g CRITICAL'
  result1="$(diff ./test/data/image.test knqyf263-vuln-image:1.2.3-test)"
  result2="$(diff ./test/data/alpine:3.15.4-result alpine:3.15.4-result)"
  [ "$result1" == '' ] && [ "$result2" == '' ]
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

@test "trivy fs with securityChecks option" {
  # trivy fs -f json --security-checks=vuln,config -o fs.test .
  ./entrypoint.sh '-a fs' '-j .' '-b json' '-s vuln,config,secret' '-h fs-scheck.test'
  result="$(diff ./test/data/fs.test fs.test)"
  [ "$result" == '' ]
}

@test "trivy repo with securityCheck secret only" {
  # trivy repo -f json -o repo.test --security-checks=secret  https://github.com/krol3/demo-trivy/
  ./entrypoint.sh '-b json' '-h repo.test' '-s secret' '-a repo' '-j https://github.com/krol3/demo-trivy/'
  result="$(diff ./test/data/repo.test repo.test)"
  [ "$result" == '' ]
}