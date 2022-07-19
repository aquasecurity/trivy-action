#!/usr/bin/env bats
load '/usr/lib/bats-support/load.bash'
load '/usr/lib/bats-assert/load.bash'

@test "trivy image" {
  # trivy image --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image.test' '-g CRITICAL'
  result="$(diff ./test/data/image.test image.test)"
  [ "$result" == '' ]
}

@test "trivy config sarif report" {
  # trivy config --format sarif --output  config-sarif.test .
  ./entrypoint.sh '-a config' '-b sarif' '-h config-sarif.test' '-j .'
  result="$(diff ./test/data/config-sarif.test config-sarif.test)"
  [ "$result" == '' ]
}

@test "trivy config" {
  # trivy config --format json --output config.test .
  ./entrypoint.sh '-a config' '-b json' '-j .' '-h config.test'
  result="$(diff ./test/data/config.test config.test)"
  [ "$result" == '' ]
}

@test "trivy rootfs" {
  # trivy rootfs --format json --output rootfs.test .
  ./entrypoint.sh '-a rootfs' '-b json' '-j .' '-h rootfs.test'
  result="$(diff ./test/data/rootfs.test rootfs.test)"
  [ "$result" == '' ]
}

@test "trivy fs" {
  # trivy fs --format json --output fs.test .
  ./entrypoint.sh '-a fs' '-b json' '-j .' '-h fs.test'
  result="$(diff ./test/data/fs.test fs.test)"
  [ "$result" == '' ]
}

@test "trivy fs with securityChecks option" {
  # trivy fs --format json --security-checks=vuln,config --output fs-scheck.test .
  ./entrypoint.sh '-a fs' '-b json' '-j .' '-s vuln,config' '-h fs-scheck.test'
  result="$(diff ./test/data/fs-scheck.test fs-scheck.test)"
  [ "$result" == '' ]
}

@test "trivy repo with securityCheck vuln only" {
  # trivy repo --output repo.test --security-checks=vuln https://github.com/krol3/demo-trivy/
  ./entrypoint.sh '-h repo.test' '-s vuln' '-a repo' '-j https://github.com/krol3/demo-trivy/'
  result="$(diff ./test/data/repo.test repo.test)"
  [ "$result" == '' ]
}

@test "trivy fs with securityCheck secret only" {
  # trivy fs --format json --output secret.test --security-checks=secret ./test/data/secret/
  ./entrypoint.sh '-h secret.test' '-s secret' '-a fs' '-b json' '-j ./test/data/secret/'
  result="$(diff ./test/data/secret.test secret.test)"
  [ "$result" == '' ]
}

@test "trivy image with trivyIgnores option" {
  # cat ./test/data/.trivyignore1 ./test/data/.trivyignore2 > ./trivyignores ; trivy image --severity CRITICAL  --output image-trivyignores.test --ignorefile ./trivyignores knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image-trivyignores.test' '-g CRITICAL' '-t ./test/data/.trivyignore1,./test/data/.trivyignore2'
  result="$(diff ./test/data/image-trivyignores.test image-trivyignores.test)"
  [ "$result" == '' ]
}

@test "trivy image with sbom output" {
  # trivy image --format  github knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh  "-a image" "-b github" "-i knqyf263/vuln-image:1.2.3"
  assert_output --partial '"package_url": "pkg:apk/ca-certificates@20171114-r0",' # TODO: Output contains time, need to mock
}

@test "trivy repo with trivy.yaml config" {
  # trivy --config=./data/trivy.yaml fs --security-checks=config,vuln --output=yamlconfig.test .
  run ./entrypoint.sh "-a fs" "-j ." "-s config,vuln" "-v ./test/data/trivy.yaml" "-h yamlconfig.test"
  result="$(diff ./test/data/yamlconfig.test yamlconfig.test)"
  [ "$result" == '' ]
}