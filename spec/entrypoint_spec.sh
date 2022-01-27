#shellcheck shell=sh

Describe 'Entrypoint '

It 'Test scan-type image'
  When run source ./entrypoint.sh '-i knqyf263/vuln-image:1.2.3'
  The stdout should match pattern '*Detected OS: alpine*'
End

It 'Test scan-type image and format json'
  When run source ./entrypoint.sh '-i knqyf263/vuln-image:1.2.3' '-b json'
  The stdout should match pattern '*"ArtifactName": "knqyf263/vuln-image:1.2.3",*'
End

It 'Test scan-type conf'
  When run source ./entrypoint.sh '-a config' '-j .'
  The stdout should match pattern '*Detected config files:*'
End

It 'Test scan-type rootfs'
  When run source ./entrypoint.sh '-a rootfs' '-j .'
  The stdout should match pattern '*Number of language-specific files*'
End

End