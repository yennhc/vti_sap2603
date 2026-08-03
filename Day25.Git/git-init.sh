#!/bin/bash

# 1. Initialize the repository locally
git init

# 2. Configure git (if not done globally)
git config user.name "yennhc"
git config user.email "yen.nguyenhoacat@gmail.com"

# 3. Add your files
git add README.md

# 4. Make your first commit
git commit -m "Initial commit"

# 5. Rename branch to main (if needed)
git branch -M main

# 6. Add the remote
git remote add origin http://172.19.78.62:3000/yennhc/test2.git

# 7. Push to remote (with -u to set upstream)
git push -u origin main