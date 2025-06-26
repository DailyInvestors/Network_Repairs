Description: A daily script designed for Crontab to email a disk space report directly to your email.

Requirements:
1. Must have Linux
2. Must have Bash
3. Must have Crontab
4. Must have either mailutils or mailx for email alert.

Installation:
1. Touch check_disk_space.sh.
2. Copy the original source file.
3. Use you favorite editor, and paste the contents.
4. Chmod 777
5. Add script to Cronjobs
0 1 *** /use/local/bin/check_disk_space.sh > /dev/null 2>&1


Note: Remember to place your email inside of the pasted code.

We appreciate any and all donations, to help us continue our Research until awarded a Bug Bounty/Patch. Thank You.