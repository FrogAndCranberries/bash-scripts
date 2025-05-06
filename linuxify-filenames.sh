#!/bin/bash

# Run with a directory as single argument
# Iterates through all files and subdirectories and changes all file and directory names into lower-kebab-case:
# All whitespace and _ replaced by -
# All Capital letters replaced by lowercase
# Czech letters replaced by english version (ščřžýáíéěůú -> scrzyaieuě)
# Punctuation removed: ,'-
# In case of conflicting new names, name new files sequentially: file.txt, file-1.txt, file-2.txt...
