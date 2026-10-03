WITH tb_transacoes AS (
    SELECT  *
    FROM    workspace.tmw_loyalty.transacoes
    --WHERE   DATE(DtCriacao) < '2026-06-01'
    --        AND DATE(DtCriacao) >= '2026-06-01' - INTERVAL 28 DAYS
    WHERE   DATE(DtCriacao) < '{date}'
            AND DATE(DtCriacao) >= '{date}' - INTERVAL 28 DAYS
),

-- Período de 28 dias anterior
tb_transacoes_ant AS (
    SELECT  *
    FROM    workspace.tmw_loyalty.transacoes
    --WHERE   DATE(DtCriacao) < '2026-06-01' - INTERVAL 28 DAYS
    --        AND DATE(DtCriacao) >= '2026-06-01' - INTERVAL 56 DAYS
    WHERE   DATE(DtCriacao) < '{date}' - INTERVAL 28 DAYS
            AND DATE(DtCriacao) >= '{date}' - INTERVAL 56 DAYS
),

tb_cliente_agg AS (
    SELECT  IdCliente,
            COUNT(DISTINCT DATE(DtCriacao)) AS qtFrequencia,
            SUM(QtdePontos) AS qtPontos,
            SUM(CASE WHEN QtdePontos > 0 THEN QtdePontos ELSE 0 END) AS qtPontosPositivos,
            MIN(DATE_DIFF('{date}', DATE(DtCriacao))) AS recencia,
            --MIN(DATE_DIFF('2026-06-01', DATE(DtCriacao))) AS recencia,
            COUNT(idTransacao) AS QtdeTransacoes
    FROM    tb_transacoes
    GROUP BY ALL
),

tb_cliente_agg_ant AS (
    SELECT  IdCliente,
            COUNT(DISTINCT DATE(DtCriacao)) AS qtFrequencia,
            SUM(QtdePontos) AS qtPontos,
            SUM(CASE WHEN QtdePontos > 0 THEN QtdePontos ELSE 0 END) AS qtPontosPositivos,
            COUNT(idTransacao) AS QtdeTransacoes
    FROM    tb_transacoes_ant
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
            min(CASE WHEN t3.DescNomeProduto = 'Presença Streak' THEN date_diff('{date}', date(t1.DtCriacao)) END) AS DiasUltimoStreak,
            --MIN(CASE WHEN t3.DescNomeProduto = 'Presença Streak' THEN DATE_DIFF('2026-06-01', date(t1.DtCriacao)) END) AS DiasUltimoStreak,
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
            MAX(DATE_DIFF('{date}', DATE(t1.dtCriacao))) AS diasPrimeiraTransacao,
            --MAX(DATE_DIFF('2026-06-01', DATE(t1.dtCriacao))) AS diasPrimeiraTransacao,
            COUNT(DISTINCT DATE(t1.DtCriacao)) AS freqVida,
            SUM(t1.QtdePontos) AS saldoDia
    FROM    workspace.tmw_loyalty.transacoes AS t1
    WHERE   DATE(DtCriacao) < '{date}'
    --WHERE   DATE(DtCriacao) < '2026-06-01'
    GROUP BY ALL
),

tb_join AS (
    SELECT  t1.*,

            /*
            -- Percentual de variação da média de avaliações entre 1 mês e 12 meses
            (AVG(CASE WHEN  dtv.dtPedido > '{date}' - INTERVAL 28 DAY THEN vlNota END) - 
                AVG(CASE WHEN  dtv.dtPedido > '{date}' - INTERVAL 336 DAY THEN vlNota END)) 
                    / AVG(CASE WHEN  dtv.dtPedido > '{date}' - INTERVAL 336 DAY THEN vlNota END)
                 AS pctTendencia1m_12m,
            */              
            
            -- Percentual de variação da média entre 28 e 56 dias
            -- (média 28d - média 56d) / média 56d
            TRY_DIVIDE(
                    t1.qtFrequencia - (t1_ant.qtFrequencia + t1.qtFrequencia) / 2, 
                    (t1_ant.qtFrequencia + t1.qtFrequencia) / 2
            ) AS pctTendenciaFrequencia28d_56d,
            TRY_DIVIDE(
                    t1.qtpontos - (t1_ant.qtpontos + t1.qtpontos) / 2, 
                    (t1_ant.qtpontos + t1.qtpontos) / 2
            ) AS pctTendenciaPontos28d_56d,
            TRY_DIVIDE(
                    t1.qtpontospositivos - (t1_ant.qtpontospositivos + t1.qtpontospositivos) / 2, 
                    (t1_ant.qtpontospositivos + t1.qtpontospositivos) / 2
            ) AS pctTendenciaPontosPositivos28d_56d,
            TRY_DIVIDE(
                    t1.qtFrequencia - (t1_ant.qtdetransacoes + t1.qtdetransacoes) / 2, 
                    (t1_ant.qtdetransacoes + t1.qtdetransacoes) / 2
            ) AS pctTendenciaTransacoes28d_56d,
            
            --TRY_DIVIDE(t1.qtFrequencia, t1_ant.qtFrequencia) AS txFrequencia28d,
            --TRY_DIVIDE(t1.qtpontos, t1_ant.qtpontos) AS txPontos28d,
            --TRY_DIVIDE(t1.qtpontospositivos, t1_ant.qtpontospositivos) AS txPontosPositivos28d,
            --TRY_DIVIDE(t1.qtdetransacoes, t1_ant.qtdetransacoes) AS txTransacoes28d,
            
            (t1.qtPontosPositivos - (SELECT AVG(qtPontosPositivos) FROM tb_cliente_agg)) 
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
            LEFT JOIN tb_cliente_agg_ant AS t1_ant
                ON t1_ant.idcliente = t1.idcliente
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

SELECT  '{date}' AS dtRef,
        --'2026-06-01' AS dtRef,
        t1.*,
        t2.avgDiasEntreTransacoes
FROM    tb_join As t1
        LEFT JOIN tb_intervalo_transacoes As t2
            ON t1.IdCliente = t2.IdCliente