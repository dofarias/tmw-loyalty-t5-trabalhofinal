WITH tb_transacoes AS (
    SELECT  *
    FROM    workspace.tmw_loyalty.transacoes
    WHERE   DtCriacao < '2026-06-01'
            AND DtCriacao >= '2026-06-01' - interval 28 days
    --WHERE DtCriacao < '{date}'
    --AND DtCriacao >= '{date}' - interval 28 days
),

tb_cliente_agg AS (
    SELECT  IdCliente,
            COUNT(DISTINCT DATE(DtCriacao)) AS qtFrequencia,
            SUM(QtdePontos) AS qtPontos,
            SUM(CASE WHEN QtdePontos > 0 THEN QtdePontos ELSE 0 END) AS qtPontosPositivos,
            --MIN(ATE_DIFF('{date}', DtCriacao)) AS recencia,
            MIN(DATE_DIFF('2026-06-01', DtCriacao)) AS recencia,
            COUNT(idTransacao) AS QtdeTransacoes
    FROM    tb_transacoes
    GROUP BY ALL
),

tb_cliente_produto AS (
    SELECT  IdCliente,
            COUNT(DISTINCT CASE WHEN t3.DescNomeProduto = 'ChatMessage' THEN t1.idTransacao ELSE NULL END) 
                / COUNT(DISTINCT t1.IdTransacao) AS pctTransacaoChatMessage,
            COUNT(DISTINCT CASE WHEN t3.DescNomeProduto = 'Lista de presença' THEN t1.idTransacao ELSE NULL END) 
                / COUNT(DISTINCT t1.IdTransacao) AS pctTransacaoListapresenca,
            COUNT(DISTINCT CASE WHEN t3.DescNomeProduto = 'Presença Streak' THEN t1.idTransacao ELSE NULL END) 
                / COUNT(DISTINCT t1.IdTransacao) AS pctTransacaoPresencaStreak,
            COUNT(DISTINCT CASE WHEN t3.DescNomeProduto = 'Resgatar Ponei' THEN t1.idTransacao ELSE NULL END) 
                / COUNT(DISTINCT t1.IdTransacao) AS pctTransacaoResgatarPonei,
            COUNT(DISTINCT CASE WHEN t3.DescNomeProduto = 'Troca de Pontos StreamElements' THEN t1.idTransacao ELSE NULL END) 
                / COUNT(DISTINCT t1.IdTransacao) AS pctTransacaoTrocaPontosStreamElements,
            MAX(CASE WHEN t3.DescNomeProduto = 'Presença Streak' THEN 1 ELSE 0 END) AS flStreak,
            --min(CASE WHEN t3.DescNomeProduto = 'Presença Streak' THEN date_diff('{date}', t1.DtCriacao) end) AS --DiasUltimoStreak,
            MIN(CASE WHEN t3.DescNomeProduto = 'Presença Streak' THEN DATE_DIFF('2026-06-01', t1.DtCriacao) END) AS DiasUltimoStreak,
            COUNT(DISTINCT t2.IdProduto) AS qtdeProdutoDistintos,
            -- Share de dia da semana
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 1 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoDomingo,
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 2 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoSegunda,
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 3 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoTerca,
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 4 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoQuarta,
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 5 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoQuinta,
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 6 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoSexta,
            COUNT(DISTINCT CASE WHEN DAYOFWEEK(t1.DtCriacao) = 7 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoSabado,
            -- Share por periodo do dia
            COUNT(DISTINCT CASE WHEN HOUR(t1.DtCriacao) >= 0 AND HOUR(t1.DtCriacao) < 6 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoMadrugada,
            COUNT(DISTINCT CASE WHEN HOUR(t1.DtCriacao) >= 6 AND HOUR(t1.DtCriacao) < 12 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoManha,
            COUNT(DISTINCT CASE WHEN HOUR(t1.DtCriacao) >= 12 AND HOUR(t1.DtCriacao) < 18 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoTarde,
            COUNT(DISTINCT CASE WHEN HOUR(t1.DtCriacao) >= 18 THEN t1.idTransacao END)
                / COUNT(DISTINCT t1.idTransacao) AS pctTransacaoNoite
    FROM    tb_transacoes AS t1
            LEFT JOIN workspace.tmw_loyalty.transacao_produto AS t2
                ON t1.IdTransacao = t2.idTransacao
            LEFT JOIN workspace.tmw_loyalty.produtos AS t3
                ON t2.IdProduto = t3.IdProduto
    GROUP BY ALL
    ORDER BY 2 DESC
),

tb_vida AS (
    SELECT  IdCliente,
            --MAX(DATE_DIFF('{date}', t1.dtCriacao)) AS diasPrimeiraTransacao,
            MAX(DATE_DIFF('2026-06-01', t1.dtCriacao)) AS diasPrimeiraTransacao,
            COUNT(DISTINCT DATE(t1.DtCriacao)) AS freqVida,
            SUM(t1.QtdePontos) AS saldoDia
    FROM    workspace.tmw_loyalty.transacoes AS t1
    --WHERE DtCriacao < '{date}'
    WHERE   DtCriacao < '2026-06-01'
    GROUP BY ALL
),

tb_join AS (
    SELECT  t1.*,
            (qtPontosPositivos - (SELECT AVG(qtPontosPositivos) FROM tb_cliente_agg)) 
                / (SELECT stddev(qtPontosPositivos) FROM tb_cliente_agg) AS zScore,
            t2.pctTransacaoChatMessage,
            t2.pctTransacaoListapresenca,
            t2.pctTransacaoPresencaStreak,
            t2.pctTransacaoResgatarPonei,
            t2.pctTransacaoTrocaPontosStreamElements,
            t2.flStreak,
            t2.DiasUltimoStreak,
            t2.qtdeProdutoDistintos,
            t2.pctTransacaoDomingo,
            t2.pctTransacaoSegunda,
            t2.pctTransacaoTerca,
            t2.pctTransacaoQuarta,
            t2.pctTransacaoQuinta,
            t2.pctTransacaoSexta,
            t2.pctTransacaoSabado,
            t2.pctTransacaoMadrugada,
            t2.pctTransacaoManha,
            t2.pctTransacaoTarde,
            t2.pctTransacaoNoite,
            t3.saldoDia,
            t3.diasPrimeiraTransacao,
            t3.freqVida
    FROM    tb_cliente_agg AS t1
            LEFT JOIN tb_cliente_produto AS t2
                ON t1.idcliente = t2.idcliente
            LEFT JOIN tb_vida AS t3
                ON t1.idcliente = t3.idcliente
),

tb_transacoes_ordenadas AS (
    SELECT  IdCliente,
            TO_DATE(DtCriacao) AS dtTransacao,
            LAG(TO_DATE(DtCriacao)) OVER (PARTITION BY IdCliente ORDER BY DtCriacao) AS dtTransacaoAnterior
    FROM    tb_transacoes
),

tb_intervalo_transacoes AS (
    SELECT  IdCliente,
            AVG(DATE_DIFF(DtTransacao, dtTransacaoAnterior)) AS avgDiasEntreTransacoes
    FROM    tb_transacoes_ordenadas
    WHERE   dtTransacaoAnterior IS NOT NULL
    GROUP BY ALL
)

SELECT  --'{date}' AS dtRef,
        '2026-06-01' AS dtRef,
        t1.*,
        t2.avgDiasEntreTransacoes
FROM    tb_join As t1
        LEFT JOIN tb_intervalo_transacoes As t2
            ON t1.IdCliente = t2.IdCliente