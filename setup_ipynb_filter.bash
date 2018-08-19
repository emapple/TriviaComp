#!/bin/bash
# This script will setup the git repository where it is executed to ignore
# output, metadata, and execution count data from ipython/jupyter notebooks
# anywhere in the local tree.  It will install a fast JSON parser called jq
# to help in this effort.  This will take ~50 MB on your disk, but it's likely
# a good idea to add the whole jq directory to .gitignore.

# with guidance from http://timstaley.co.uk/posts/making-git-and-jupyter-notebooks-play-nice/

# Note that this script will overwrite .gitconfig and .gitattributes in its
# current state.

# Prereqs for jq compilation are just gcc, make, and autotools.
# jq is also available via apt/pacman/homebrew/etc.

# I may modify this in the future to integrate better with a system jq.
# Presently, it just blindly builds it in the root of the repository.


# clone and install jq for notebook metadata stripping, including oniguruma submodule
if [ -f jq/bin/jq ]; then
	echo "jq appears to be in order."
else
	echo "No jq, building it now."
	mkdir jq
	git clone https://github.com/stedolan/jq.git jq/repo
	cd jq/repo
	git submodule update --init
	autoreconf -fi
	./configure --with-oniguruma=builtin --disable-maintainer-mode --prefix=$PWD/..
	make
	make install
fi

# update .git/config with notebook stripping rule
cat << EOF > .gitconfig
[filter "nbstrip_full"]
clean = "jq/bin/jq --indent 1 \\
	'(.cells[] | select(has(\"outputs\")) | .outputs) = []  \\
	| (.cells[] | select(has(\"execution_count\")) | .execution_count) = null  \\
	| .metadata = {\"language_info\": {\"name\": \"python\", \"pygments_lexer\": \"ipython3\"}} \\
	| .cells[].metadata = {} \\
	'"
smudge = cat
required = true
EOF

# update .gitattributes to include filter for *.ipynb
cat << EOF > .gitattributes
**.ipynb filter=nbstrip_full
EOF

# update git configuration to include our new .gitconfig
git config --local include.path ../.gitconfig
