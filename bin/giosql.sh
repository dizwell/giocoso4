#!/usr/bin/env bash
####################################################################
#
# giosql: routine for processing passed parameters into a sql statement that Giocoso can run to select music to play
#
####################################################################
# ======================================================================================================
# We arrive here with a pool of 'candidate composers' for the next play, in the form of the
# SEARCHARTIST array that is passed to this script from the calling default search script.. Our
# job here is therefore to randomly select **recordings** by those composers.
# ======================================================================================================

# ======================================================================================================
# Now construct a proper multi-filtered SQL statement. The aim of this SQL, in whichever database, is
# to 1) filter recordings by searchartist; 2) to take that list of filtered recordings and partition 
# or group it by composer; 3) to order the recordings *within* each composer group randomly and assign a 
# ranking to the result, so that one of the recordings is assigned a ranking of 1 (effectively a faux 
# row number); and then 4) select randomly from all recordings assigned a rank of 1, up to the limit 
# specified by the 'number of plays per cycle' limit configured.
#
# The point of doing all that is to say, "If you have asked for 10 plays per cycle, you shall have
# 10 randomly-selected recordings, **but there'll only be one per composer**. Which doesn't prevent
# the same composer popping up in the //next// 10 plays (that's what the time bar is for, if you want
# to stop that happening), but it at least makes every cycle of plays (of whatever number) richly
# varied and diverse.
# ======================================================================================================

SQLSTMT="select filesuffix from (
  select * from (
  select
    rank() over ( partition by global_recordings.composer
  order by
    rand()) AS ranking,
    global_recordings.composer AS composer,
    global_recordings.filesuffix AS filesuffix,
    global_recordings.duration AS duration,
    global_recordings.rechashvalue AS rechashvalue
  from
    global_recordings
  where
    composer in 
    $SEARCHARTIST
  order by
    global_recordings.composer,
    rank() over ( partition by global_recordings.composer
  order by
    rand())
) t 
where ranking=1 order by rand()
limit $RESULTLIMIT) b"

echo "$SQLSTMT"
