# gitlab-utils
stepping stone GitLab related scripts

## gitlab-backup.sh
GitLab backup script

### Overview
In order to achieve a consistent backup, one needs to make sure, that all the involved data and services (PostgreSQL, Redis, Git repositories) are backed up atomically or within read-only mode. Unfortunately, at the time of writing (2015-07), there [seems to be no way of putting Gitlab into a maintenance](http://feedback.gitlab.com/forums/176466-general/suggestions/6721698-put-gitlab-in-maintenance-mode) (read-only) mode. Gitlab provides a [tarball backup rake task](https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/raketasks/backup_restore.md), but this is [neither consistent](http://stackoverflow.com/questions/24066283/how-to-make-a-consistent-gitlab-backup) nor is it suited for large environments. It would also be possible to take an LVM snapshot of the underlying file system, which however implies that all the data (PostgreSQL, Redis, Git repositories etc.) have to be on the same server and file system and that you are confident with a binary database backup strategy (instead of database dumps).

For the reasons mentioned above, it was decided to go with a rather traditional, conservative backup approach: The services which might be able to modify data and brake data consistency during the backup run, will be stopped before the backup starts and started afterwards. As result of this, the users won't be able to access the GitLab service during the backup run. This may or may not be a problem and depend on your specific requirements.

### Description
The script merely acts as a backup wrapper script of other existing scripts.

First it informs a monitoring system (currently Zabbix), of the upcoming backup run and puts the affected services into maintenance mode. It then stops the unicorn and sidekiq services to prevent access to the GitLab service.
Then, the PostgresSQL database will be dumped and a new Redis snapshot will be created (if necessary). After that, the actual (file) backup script will be called, to save all the configuration, dumps and Git repositories.
Finally, the services will be restarted and the monitoring system informed, regarding the end of the backup maintenance period.
