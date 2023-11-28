#!/usr/bin/env bats
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file

@test "trivy repo with securityCheck secret only" {
  # trivy repo --format json --output repo.test --scanners=secret https://github.com/krol3/demo-trivy/
  run ./entrypoint.sh '-b json' '-h repo.test' '-s secret' '-a repo' '-j https://github.com/krol3/demo-trivy/'
  run diff repo.test ./test/data/repo.test
  echo "$output"
  assert_files_equal repo.test ./test/data/repo.test
}

@test "trivy image" {
  # trivy image --severity CRITICAL --output image.test knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image.test' '-g CRITICAL'
  run diff image.test ./test/data/image.test
  echo "$output"
  assert_files_equal image.test ./test/data/image.test
}

@test "trivy config sarif report" {
  # trivy config --format sarif --output  config-sarif.test .
  run ./entrypoint.sh '-a config' '-b sarif' '-h config-sarif.test' '-j .'
  run diff config-sarif.test ./test/data/config-sarif.test
  echo "$output"
  assert_files_equal config-sarif.test ./test/data/config-sarif.test
}

@test "trivy config" {
  # trivy config --format json --output config.test .
  run ./entrypoint.sh '-a config' '-b json' '-j .' '-h config.test'
  run diff config.test ./test/data/config.test
  echo "$output"
  assert_files_equal config.test ./test/data/config.test
}

@test "trivy rootfs" {
  # trivy rootfs --output rootfs.test .
  run ./entrypoint.sh '-a rootfs' '-j .' '-h rootfs.test'
  run diff rootfs.test ./test/data/rootfs.test
  echo "$output"
  assert_files_equal rootfs.test ./test/data/rootfs.test
}

@test "trivy fs" {
  # trivy fs --output fs.test .
  run ./entrypoint.sh '-a fs' '-j .' '-h fs.test'
  run diff fs.test ./test/data/fs.test
  echo "$output"
  assert_files_equal fs.test ./test/data/fs.test
}

@test "trivy fs with securityChecks option" {
  # trivy fs --format json --scanners=vuln,config --output fs-scheck.test .
  run ./entrypoint.sh '-a fs' '-b json' '-j .' '-s vuln,config,secret' '-h fs-scheck.test'
  run diff fs-scheck.test ./test/data/fs-scheck.test
  echo "$output"
  assert_files_equal fs-scheck.test ./test/data/fs-scheck.test
}


@test "trivy image with trivyIgnores option" {
  # cat ./test/data/.trivyignore1 ./test/data/.trivyignore2 > ./trivyignores ; trivy image --severity CRITICAL  --output image-trivyignores.test --ignorefile ./trivyignores knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh '-a image' '-i knqyf263/vuln-image:1.2.3' '-h image-trivyignores.test' '-g CRITICAL' '-t ./test/data/.trivyignore1,./test/data/.trivyignore2'
  run diff image-trivyignores.test ./test/data/image-trivyignores.test
  echo "$output"
  assert_files_equal image-trivyignores.test ./test/data/image-trivyignores.test
}

@test "trivy image with sbom output" {
  # trivy image --format  github knqyf263/vuln-image:1.2.3
  run ./entrypoint.sh  "-a image" "-b github" "-i knqyf263/vuln-image:1.2.3"
  assert_output --partial '"package_url": "pkg:apk/ca-certificates@20171114-r0",' # TODO: Output contains time, need to mock
}

@test "trivy image with trivy.yaml config" {
  # trivy --config=./test/data/trivy.yaml image alpine:3.10
  run ./entrypoint.sh "-v ./test/data/trivy.yaml" "-a image" "-i alpine:3.10"
  run diff yamlconfig.test ./test/data/yamlconfig.test
  echo "$output"
  assert_files_equal yamlconfig.test ./test/data/yamlconfig.test
}

@test "trivy config with terraform variables" {
  # trivy config --format json --severity  MEDIUM --output  tfvars.test --tf-vars  ./test/data/dev.tfvars ./test/data  
  run ./entrypoint.sh "-a config"  "-j ./test/data" "-h tfvars.test" "-g MEDIUM" "-x dev.tfvars" "-b json"
  run diff tfvars.test ./test/data/tfvars.test 
  echo "$output"
  assert_files_equal tfvars.test ./test/data/tfvars.test
}