
The purpose of oramon.sh is to monitor latency of Oracle I/O operations

	Usage: oramon.sh [username] [password] [host] [sid] <port=1521> <runtime=3600>


Output:

	RUN_TIME=-1
	COLLECT_LIST=
	FAST_SAMPLE=iolatency
	TARGET=172.16.100.134:NFS
	DEBUG=0
	
	Connected, starting collect at Thu Jul 5 09:42:26 PDT 2012
	starting stats collecting

	   single block       logfile write       multi block      direct read   direct read temp    direct write temp
	   ms      IOP/s        ms    IOP/s       ms    IOP/s       ms    IOP/s       ms    IOP/s         ms     IOP/s
	    3.92     1.32     6.86      .03     1.35      .00      .75      .00               .00                     0
	     .57   187.83     1.16    20.50               .00               .00               .00                     0
	     .59   287.60     1.19    21.60     1.00      .00     2.11     6.30               .00                     0
	     .51   174.00     1.15    22.67               .00               .00               .00                     0
	     .51   228.20     1.21    25.60               .00               .00               .00                     0
	

