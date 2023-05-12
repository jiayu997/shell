### 依赖环境

- jq软件包版本>=1.6
- docker
- curl

### 获取镜像坐标

该功能主要是获取harbor所有project下面所有image，image tags，并在当前路径下生成镜像坐标文件harbor_image_list

```shell
# 使用方法
	bash harbor.sh get_image_cordinate
```

### 备份harbor

该功能用于将整个harbor项目中所有镜像备份到本地

```shell
# 使用方法
	bash harbor.sh get_image_cordinate
	bash harbor.sh backup_harbor
```

### 备份恢复

将当前路径下的harbor-backup/镜像加载到本地

```shell
# 使用方法
	bash harbor.sh backup_restore
```

### 本地镜像推送到harbor

将本地镜像推送到harbor（harbor中如果不存在的项目会自动创建）

```shell
# 使用方法
	bash harbor.sh local_push_harbor
```

### harbor迁移

- `如果新老harbor同时存在`

```shell
# 获取镜像坐标
	bash harbor.sh get_image_cordinate

# 推送镜像到新harbor
	bash harbor.sh push_new_harbor
```

- 如果要先停掉老harbor，再起新harbor保证尽可能不同其他配置

```shell
# 停掉老harbor前执行下列命令
	bash harbor.sh get_image_cordinate
	bash harbor.sh backup_harbor

# 然后停掉老harbor，待新harbor起来后，运行下列命令
	bash harbor.sh backup_restore
	bash harbor.sh local_push_harbor
```

