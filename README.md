# 2026 China College IC Competition
集成电路创新创业大赛代码仓库
## 工作流程及要求

### 代码初始化
    $ git clone git@github.com:lihaoyan02/IC_Competition.git
    # 切换开发分支，拉最新
    $ git checkout develop
    $ git pull origin develop
    # 建立自己分支
    $ cd IC_Competition
    $ git checkout -b [你的分支名字]

### 代码提交
    # 在你自己的分支下
    $ git add .
    $ git commit

    #建议，创建新的分支进行提交
    $ git checkout -b [提交分支] 

    #同步更新 develop
    $ git checkout develop
    $ git pull origin develop

    $ git checkout [提交分支]
    $ git merge develop

    # 解决冲突（如有），测试
    $ git push origin [提交分支]

### 网页提Pull Request
