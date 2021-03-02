#!/usr/bin/env bash
set -Eeuo pipefail

versions=( */ )
versions=( "${versions[@]%/}" )

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#
	EOH
}

for version in "${versions[@]}"; do
    if [[ "$version" == "files" ]]; then
    continue
    fi

    rcVersion="${version%-rc}"

    echo $version

    # "7", "5", etc
    majorVersion="${rcVersion%%.*}"
    # "2", "1", "6", etc
    minorVersion="${rcVersion#$majorVersion.}"
    minorVersion="${minorVersion%%.*}"

    dockerfiles=()

    baseDockerfile=Dockerfile.template

    for variant in cli apache fpm; do
        [ -d "$version/$variant" ] || continue

        for distribution in buster stretch; do
          [ -d "$version/$variant/$distribution" ] || continue

          for debug in debug no-debug; do
              { generated_warning; cat "$baseDockerfile"; } > "$version/$variant/$distribution/$debug/Dockerfile"

              echo "Generating $version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $variant-Dockerfile-block-*"
              gawk -i inplace -v variant="$variant" '
                  $1 == "##</autogenerated>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<autogenerated>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$version/$variant/$distribution/$debug/Dockerfile"

              echo "Generating $version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $version-Dockerfile-block-*"
              gawk -i inplace -v variant="$version" '
                  $1 == "##</version>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<version>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$version/$variant/$distribution/$debug/Dockerfile"

              debugBlock="$debug"

              if [ debug = 'debug' ]; then
                versionDebugFile="${debug}-${version}-Dockerfile-block-1"

                if [ -f $versionDebugFile ]; then
                  debugBlock="${debug}-${version}"
                else
                  debugBlock="$debug"
                fi
              fi
              
              echo "Generating $version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $debugBlock-Dockerfile-block-*"
              gawk -i inplace -v variant="$debugBlock" '
                  $1 == "##</debug>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<debug>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$version/$variant/$distribution/$debug/Dockerfile"

              echo "Generating $version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $distribution-Dockerfile-block-*"
              gawk -i inplace -v distribution="$distribution" '
                  $1 == "##</distribution>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<distribution>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$version/$variant/$distribution/$debug/Dockerfile"

              if [ -d "files/$variant/" ]; then
                cp -rf "files/$variant/" $version/$variant/$distribution/$debug
              fi

              if [ -d "files/$debug/" ]; then
                cp -rf "files/$debug/" $version/$variant/$distribution/$debug
              fi

              if [ -d "files/$distribution/$debug/" ]; then
                cp -rf "files/$distribution/$debug/" $version/$variant/$distribution/$debug
              fi

              if [ -d "files/$version/$debug/" ]; then
                cp -rf "files/$version/$debug/" $version/$variant/$distribution/$debug
              fi

              # remove any _extra_ blank lines created by the deletions above
              awk '
                  NF > 0 { blank = 0 }
                  NF == 0 { ++blank }
                  blank < 2 { print }
              ' "$version/$variant/$distribution/$debug/Dockerfile" > "$version/$variant/$distribution/$debug/Dockerfile.new"
              mv "$version/$variant/$distribution/$debug/Dockerfile.new" "$version/$variant/$distribution/$debug/Dockerfile"

              # automatic `-slim` for stretch
              # TODO always add slim once jessie is removed
              gsed -ri \
                  -e 's!%%PHP_TAG%%!'"$version"'!' \
                  -e 's!%%IMAGE_VARIANT%%!'"$variant"'!' \
                  -e 's!%%DISTRIBUTION%%!'"$distribution"'!' \
                  "$version/$variant/$distribution/$debug/Dockerfile"
              dockerfiles+=( "$version/$variant/$distribution/$debug/Dockerfile" )
          done
        done
    done
done
