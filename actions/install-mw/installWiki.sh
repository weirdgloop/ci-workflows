#! /bin/bash
set -euo pipefail

MW_BRANCH="${MW_BRANCH:?MW_BRANCH must be set}"
EXTENSION_NAME="${EXTENSION_NAME:?EXTENSION_NAME must be set}"
MW_GIT_ORIGIN="${MW_GIT_ORIGIN:?MW_GIT_ORIGIN must be set}"

MW_REPO_NAME="${MW_GIT_ORIGIN##*/}"

wget "https://github.com/$MW_GIT_ORIGIN/archive/$MW_BRANCH.tar.gz" -nv

tar -zxf "$MW_BRANCH.tar.gz"
mv "$MW_REPO_NAME-$MW_BRANCH" mediawiki

cd mediawiki

echo "Applying core patches..."

# Patches in core-patches are applied to all branches to reduce duplication
CORE_PATCHES="../EarlyCopy/.github/workflows/core-patches"
for patch_file in "$CORE_PATCHES"/*.patch; do
  [ -f "$patch_file" ] || continue

  echo "Applying $(basename "$patch_file")"
  patch -p1 < "$patch_file"
done

# Each branch can have a subdirectory with patches in the core-patches folder
BRANCH_PATCHES="$CORE_PATCHES/$MW_BRANCH"

if [ -d "$BRANCH_PATCHES" ]; then
  for patch_file in "$BRANCH_PATCHES"/*.patch; do
    [ -f "$patch_file" ] || continue

    echo "Applying $(basename "$patch_file")"
    patch -p1 < "$patch_file"
  done
fi

composer install --no-ansi --no-interaction --prefer-dist
php maintenance/install.php --dbtype sqlite --dbuser root --dbname mw --dbpath $(pwd) --pass AdminPassword WikiName AdminUser

# TODO Also enable dependencies here once we support them
cat >> LocalSettings.php <<EOF
\$wgShowExceptionDetails = true;
\$wgShowDBErrorBacktrace = true;
\$wgDevelopmentWarnings = true;
wfLoadExtension( '$EXTENSION_NAME' );
EOF

# Allow adding additional settings in LocalSettings.extra.php
if [ -f "../EarlyCopy/.github/workflows/LocalSettings.extra.php" ]; then
  cat "../EarlyCopy/.github/workflows/LocalSettings.extra.php" >> LocalSettings.php
fi


cat <<EOT >> composer.local.json
{
  "require": {},
	"extra": {
		"merge-plugin": {
			"merge-dev": true,
			"include": []
		}
	}
}
EOT

# Download phpunit.xml.dist or phpunit.xml.template as they're ignored in .gitattributes
wget "https://raw.githubusercontent.com/${MW_GIT_ORIGIN}/${MW_BRANCH}/phpunit.xml.dist" -nv || \
  wget "https://raw.githubusercontent.com/${MW_GIT_ORIGIN}/${MW_BRANCH}/phpunit.xml.template" -nv
