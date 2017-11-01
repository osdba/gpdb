/*
 * xlogutils.h
 *
 * PostgreSQL transaction log manager utility routines
 *
 * Portions Copyright (c) 1996-2008, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * $PostgreSQL: pgsql/src/include/access/xlogutils.h,v 1.23 2008/01/01 19:45:56 momjian Exp $
 */
#ifndef XLOG_UTILS_H
#define XLOG_UTILS_H

#include "storage/buf.h"
#include "utils/rel.h"


extern void XLogInitRelationCache(void);
extern void XLogCheckInvalidPages(void);
extern void XLogCloseRelationCache(void);

extern Relation XLogOpenRelation(RelFileNode rnode);
extern void XLogDropRelation(RelFileNode rnode);
extern void XLogDropDatabase(Oid tblspc, Oid dbid);
extern void XLogTruncateRelation(RelFileNode rnode, BlockNumber nblocks);

extern Buffer XLogReadBuffer(Relation reln, BlockNumber blkno, bool init);

#ifdef USE_SEGWALREP
extern void XLogAOSegmentFile(RelFileNode rnode, uint32 segmentFileNum);
extern void XLogAODropSegmentFile(RelFileNode rnode, uint32 segmentFileNum);
#endif

#endif
