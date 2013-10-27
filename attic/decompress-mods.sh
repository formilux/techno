find kernel -name '*.o' | while read; do zcat <$REPLY >$REPLY- && mv $REPLY- $REPLY || rm -vf $REPLY-; done
