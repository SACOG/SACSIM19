USE NPMRDS

CREATE TABLE #test (
	grpid VARCHAR(1),
	val FLOAT
	)


INSERT INTO #test VALUES
('a',1.54766099958642),
('a',2.10534961528528),
('a',7.0710262954377),
('b',7.89149405701111),
('b',5.2773768028472),
('b',9.76967307341783),
('b',0.572985992723344),
('c',0.749200608836912),
('c',5.95249368117681),
('c',7.52809314280502),
('c',3.21007592196416),
('c',8.4624110870191),
('c',8.78718731826456)
;

WITH stdv AS (
	SELECT DISTINCT
		grpid,
		STDEV(val) OVER (ORDER BY grpid) AS std_dev
	FROM #test
	)

SELECT
	t.grpid,
	COUNT(*) AS cnt,
	AVG(val) AS avg,
	stdv.std_dev
FROM #test t
	JOIN stdv
		ON t.grpid = stdv.grpid
GROUP BY t.grpid, stdv.std_dev
ORDER BY t.grpid

DROP TABLE #test
