## My GIT Setup Guide
Git + Github Configuration

---

Create local directory:
```bash
mkdir dir-name
```

Enter directory:
```bash
cd dir-name
```

Initialize Git repo:
```bash
git init
```

Enable global credential storage:
```bash
git config --global credential.helper store
```

Username configuration:
```bash
git config user.name usernamex
```

Email configuration:
```bash
git config user.email user@mail.com
```

Add remote repo:
```bash
git remote add origin https://github.com/usernamex/repo-name.git
```

Create README file:
```bash
echo '# repo-name' > README.md
```

Add files to staging area:
```bash
git add .
```

Commit the changes:
```bash
git commit -m 'first commit'
```

Push to Github: (can say main instead of master)
```bash
git push -u origin master
```

Well done!
