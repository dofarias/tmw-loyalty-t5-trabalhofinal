WITH tb_usario_curso AS (
    SELECT  t1.idTMWCliente,
            t2.descSlugCurso,
            MIN(DATE(dtCriacao)) AS dtInicioCurso,
            MAX(DATE(dtCriacao)) AS dtUltimoEp,
            DATE_DIFF(MAX(DATE(dtCriacao)), MIN(DATE(dtCriacao))) AS diasEntrePrimeUltimo,
            COUNT(*) AS qtEpCurso,
            SUM(CASE WHEN DATE(t2.DtCriacao) >= '{date}' - INTERVAL 28 DAYS THEN 1 ELSE 0 END) AS qtEpCurso28d
            --SUM(CASE WHEN DATE(t2.DtCriacao) >= '2026-06-01' - INTERVAL 28 DAYS THEN 1 ELSE 0 END) AS qtEpCurso28d
    FROM    workspace.tmw_education.usuarios_tmw AS t1
            LEFT JOIN workspace.tmw_education.cursos_episodios_completos AS T2
                ON t1.idUsuario = t2.idUsuario
    WHERE   DATE(t2.dtCriacao) < '{date}'
    --WHERE   DATE(t2.dtCriacao) < '2026-06-01'
    GROUP BY ALL
),

tb_curso AS (
    SELECT  descSlugCurso,
            COUNT(*) AS qtEpsCurso
    FROM    workspace.tmw_education.cursos_episodios
    GROUP BY ALL
),

tb_curso_avanco AS (
    SELECT  t1.*,
            t1.qtEpCurso / t2.qtepscurso AS pctCursoCompleto
    FROM    tb_usario_curso AS t1
            LEFT JOIN tb_curso AS t2
            ON t1.descslugcurso = t2.descslugcurso
),

tb_agg AS (
    SELECT  idTMWCliente AS idCliente,
            COUNT(DISTINCT descslugcurso) AS qtdCursosIniciados,
            COUNT(DISTINCT CASE WHEN pctCursoCompleto = 1 THEN descslugcurso ELSE NULL END) AS qtdCursosFinalizados,
            SUM(CASE WHEN descslugcurso = 'github-2025' THEN pctCursoCompleto ELSE 0 END) AS github_2025,
            SUM(CASE WHEN descslugcurso = 'python-2025' THEN pctCursoCompleto ELSE 0 END) AS python_2025,
            SUM(CASE WHEN descslugcurso = 'sql-2025' THEN pctCursoCompleto ELSE 0 END) AS sql_2025,
            SUM(CASE WHEN descslugcurso = 'pandas-2025' THEN pctCursoCompleto ELSE 0 END) AS pandas_2025,
            SUM(CASE WHEN descslugcurso = 'estatistica-2025' THEN pctCursoCompleto ELSE 0 END) AS estatistica_2025,
            AVG(diasEntrePrimeUltimo) AS avgTempoInicioUltimo,
            AVG(CASE WHEN pctCursoCompleto = 1 THEN diasEntrePrimeUltimo ELSE NULL END) AS avgTempoInicioFim,
            SUM(qtepcurso28d) AS qtEpisodiosConcluidos28d
    FROM    tb_curso_avanco
    GROUP BY ALL
)

SELECT  '{date}' AS dtRef,
        --'2026-06-01' AS dtRef,
        *
FROM    tb_agg