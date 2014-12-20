#!/bin/sh
sed -e '
	s/^@setfilename .*$/@setfilename git-integration.info/
	/^@direntry/ i \
@dircategory Development
	/^@direntry/,/^@end direntry/ s/git-integration(1)/git-integration/
'
