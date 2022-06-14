#!/usr/bin/env bats

@test "trivy image" {
  # trivy image --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-b table' '-h image.test' '-g CRITICAL'
  result="$(diff ./test/data/image.test image.test)"
  [ "$result" == '' ]
}

@test "trivy image sarif report" {
  # trivy image --severity CRITICAL -f sarif --output image-sarif.test knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-b sarif' '-h image-sarif.test' '-g CRITICAL'
  result="$(diff ./test/data/image-sarif.test image-sarif.test)"
  [ "$result" == '' ]
}

@test "trivy config" {
  # trivy config --output config.test .
  ./entrypoint.sh '-a config' '-j .' '-b table' '-h config.test'
  result="$(diff ./test/data/config.test config.test)"
  [ "$result" == '' ]
}

@test "trivy rootfs" {
  # trivy rootfs -f json --output rootfs.test .
  ./entrypoint.sh '-a rootfs' '-j .' '-b json' '-h rootfs.test'
  result="$(diff ./test/data/rootfs.test rootfs.test)"
  [ "$result" == '' ]
}

@test "trivy fs" {
  # trivy fs -f json --output fs.test .
  ./entrypoint.sh '-a fs' '-j .' '-b json' '-h fs.test'
  result="$(diff ./test/data/fs.test fs.test)"
  [ "$result" == '' ]
}

@test "trivy fs with securityChecks option" {
  # trivy fs -f json --security-checks=vuln,config --output fs-scheck.test .
  ./entrypoint.sh '-a fs' '-j .' '-b json' '-s vuln,config,secret' '-h fs-scheck.test'
  result="$(diff ./test/data/fs-scheck.test fs-scheck.test)"
  [ "$result" == '' ]
}

@test "trivy repo with securityCheck secret only" {
  # trivy repo -f json --output repo.test --security-checks=secret  https://github.com/krol3/demo-trivy/
  ./entrypoint.sh '-b json' '-h repo.test' '-s secret' '-a repo' '-j https://github.com/krol3/demo-trivy/'
  result="$(diff ./test/data/repo.test repo.test)"
  [ "$result" == '' ]
}

@test "trivy image with trivyIgnores option" {
  # cat ./test/data/.trivyignore1 ./test/data/.trivyignore2 > ./trivyignores ; trivy image --severity CRITICAL --output image-trivyignores.test --ignorefile ./trivyignores knqyf263/vuln-image:1.2.3
  ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-b table' '-h image-trivyignores.test' '-g CRITICAL' '-t ./test/data/.trivyignore1,./test/data/.trivyignore2'
  result="$(diff ./test/data/image-trivyignores.test image-trivyignores.test)"
  [ "$result" == '' ]
}
