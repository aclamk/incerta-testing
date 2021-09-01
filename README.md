# incerta-testing

My private testing func. Localized for incerta07 environment (data paths).
Probably full of other problems I am not aware of.
Uses vstart cluster settings.

Single test run:
1) compile ceph
2) modify ~/incerta-testing/testrun-rewrite-4.sh to fix block/db/wal paths, or kill running perf in background...
3) cd build
4) TEST=here-goes-my-test-run-name NEW_CLUSTER=1 FILL_CLUSTER=1 COMPRESS_MODE=none EXTRA_DEPLOY_OPTIONS="-o bluefs_buffered_io=false" ~/incerta-testing/testrun-rewrite-4.sh
5) results will be written to ~/incerta-testing/here-goes-my-test-run-name
NEW_CLUSTER=1 deploys cluster
FILL_CLUSTER=1 fills it with data

To get short report on main performance attributes:
1) cd ~/incerta-testing
2) ./report.sh here-goes-my-test-run-name


