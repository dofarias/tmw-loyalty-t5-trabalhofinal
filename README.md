# TMW Loyalty — Predição de Churn de Alunos

Trabalho final da disciplina **Case Prático em Python e Databricks** (Ciência de Dados).
Modelo de classificação que estima a **probabilidade de churn** dos alunos da plataforma **Teomewhy (TMW)** e gera um **ranking** de quem está mais propenso a abandonar a plataforma, para apoiar ações de retenção.

**Autora:** Daniele Farias

---

## Sumário

1. [O problema](#1-o-problema)
2. [Visão geral da solução](#2-visão-geral-da-solução)
3. [Estrutura do repositório](#3-estrutura-do-repositório)
4. [Dados e engenharia de variáveis (ETL)](#4-dados-e-engenharia-de-variáveis-etl)
5. [Feature Store e ABT](#5-feature-store-e-abt)
6. [Modelagem](#6-modelagem)
7. [Resultados](#7-resultados)
8. [Modelo selecionado](#8-modelo-selecionado)
9. [Importância das variáveis](#9-importância-das-variáveis)
10. [Predição e uso do modelo](#10-predição-e-uso-do-modelo)
11. [Limitações e próximos passos](#11-limitações-e-próximos-passos)
12. [Como reproduzir](#12-como-reproduzir)

---

## 1. O problema

A TMW é uma plataforma de cursos com um sistema de **pontos** (programa de fidelidade) e **cursos**. O objetivo é prever quais alunos têm maior chance de deixar de interagir com a plataforma.

| Item | Definição |
|---|---|
| **Churn (target)** | Aluno **sem nenhuma pontuação nos últimos 28 dias** |
| **Tipo de problema** | Classificação binária |
| **Saída esperada** | Probabilidade de churn, usada para **ordenar** os alunos (priorização de ações) |
| **Fontes de dados** | Tabelas de **Pontos** (transações) e **Cursos** (progresso do aluno) |

> Como o uso final é **priorização** e não decisão automática, a métrica principal de comparação foi a **ROC AUC** (qualidade da ordenação), complementada por log loss, precision, recall e F1.

## 2. Visão geral da solução

```
Pontos ──┐                                                    ┌─ Treino (80%)
         ├─► ETL ─► Feature Store ─► ABT (+ target churn) ───►├─ Teste  (20%)
Cursos ──┘          (43 variáveis)                            └─ OOT (01/06/2026)
                                          │
                                          ▼
                       8 modelos + Grid Search (StratifiedKFold, k=3)
                                          │
                                          ▼
                    Random Forest selecionado ─► Predição (01/07/2026)
```

## 3. Estrutura do repositório

| Caminho | O que é |
|---|---|
| `01 - Discovery/` | Exploração inicial dos dados e definição do problema (análises exploratórias, entendimento das tabelas e do target). *[PREENCHER: listar os arquivos da pasta]* |
| `02 - Feature Store/` | Código de construção das variáveis (ETL) das tabelas de Pontos e Cursos, versionadas por data de referência. *[PREENCHER: listar os arquivos/queries]* |
| `train.ipynb` | Treinamento: montagem da ABT, split treino/teste/OOT, pipelines de pré-processamento, Grid Search, comparação dos 8 algoritmos e treino do modelo final. |
| `train old.ipynb` | Versão anterior do treinamento, mantida como histórico. *[PREENCHER: o que mudou para a versão atual]* |
| `predict.ipynb` | Aplicação do modelo treinado sobre a base mais recente (referência 01/07/2026) para gerar a probabilidade de churn e o ranking de alunos. |
| `comparacao_modelos_churn.csv` | Tabela com as métricas de todos os modelos candidatos (a mesma apresentada na seção 7). |
| `README.md` | Este documento. |

## 4. Dados e engenharia de variáveis (ETL)

No total são **43 variáveis**: 33 originadas de **Pontos** e 10 de **Cursos**.

### 4.1 Pontos (33 variáveis)

| Grupo | Variáveis | Intuição |
|---|---|---|
| **Frequência** | frequência, frequência vida | Quantos dias o aluno pontuou (janela recente e histórico completo). |
| **Recência** | recência | Há quantos dias ocorreu a última interação. Candidata natural a preditora de churn. |
| **Volume** | qt transações, qt pontos, qt pontos positivos, saldo do dia | Intensidade de uso e acúmulo de pontos. |
| **Tendência** | pct tendência (4), z-score | Compara a atividade recente com a média do próprio aluno, indicando aceleração ou queda de engajamento. |
| **Consistência** | flag de streak, dias do último streak, média de dias entre transações | Regularidade do hábito de interagir. |
| **Mix de produtos** | share de transações por produto (5), qt de produtos distintos | Diversidade e preferência de uso dos produtos. |
| **Perfil temporal** | share por dia da semana (7), share por turno (4) | Quando o aluno costuma interagir. |
| **Tempo de casa** | dias desde a primeira transação | Maturidade do aluno na plataforma. |

### 4.2 Cursos (10 variáveis)

| Grupo | Variáveis |
|---|---|
| **Adesão** | qt de cursos iniciados, qt de cursos finalizados |
| **Progresso** | % de conclusão por curso (5 cursos) |
| **Ritmo** | média de dias entre o início e o último dia de curso, média de dias entre início e fim do curso |
| **Atividade recente** | qt de episódios concluídos nos últimos 28 dias |

### 4.3 Decisões de ETL

- **Variáveis relativas (shares e percentuais)** em vez de apenas contagens absolutas, para comparar alunos com volumes de uso muito diferentes.
- **Janela de 28 dias** nas variáveis recentes, alinhada à definição do target.
- **Tendência e z-score** para capturar *mudança de comportamento*, e não só o nível de atividade.
- **Tratamento de nulos** feito no pipeline de modelagem (seção 6), já que ausência de histórico tem significados diferentes conforme a variável.

## 5. Feature Store e ABT

A **Feature Store** armazena as variáveis de Pontos e Cursos por data de referência. A **ABT** (Analytical Base Table) é a junção da Feature Store com o **target (churn)**, garantindo que as variáveis usem apenas informação anterior à data de referência.

| Base | Período / data de referência | Uso |
|---|---|---|
| **Treino + Teste** | 01/05/2025 a 01/05/2026 | Divididas em **80% treino** / **20% teste** |
| **OOT** (*out of time*) | 01/06/2026 | Validação em período posterior ao do treino, simulando o uso real |
| **Predição** | 01/07/2026 | Base a ser pontuada pelo modelo final (target ainda desconhecido) |

**Por que usar OOT?** Um bom resultado no teste aleatório pode esconder instabilidade ao longo do tempo. A base OOT mede se o modelo continua ordenando bem em um período que ele não viu.

## 6. Modelagem

### 6.1 Algoritmos comparados

Regressão Logística (duas variações), Random Forest, Hist Gradient Boosting, XGBoost, LightGBM, CatBoost e MLP Classifier.

### 6.2 Pré-processamento por modelo

| Etapa | RL | RL 2 | RF | HGB | XGB | LGBM | CatBoost | MLP |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Imputação de nulos com 0 | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Imputação de nulos com valor máximo | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| Seleção de colunas (maior variância × target) | ✔ | ✔ | | | | | | |
| Seleção *forward* | | ✔ | | | | | | |
| Min-Max Scale | ✔ | ✔ | | | | | | ✔ |

- **Duas estratégias de imputação:** `0` para variáveis em que ausência significa "nenhuma atividade" (contagens, shares) e **valor máximo** para variáveis de tempo/recência, em que ausência significa "muito tempo sem atividade". *[CONFIRMAR: quais colunas recebem cada estratégia]*
- **Min-Max Scale** apenas onde o algoritmo é sensível à escala (regressão logística e rede neural); modelos de árvore dispensam.
- **Seleção de variáveis** apenas nas regressões logísticas, que sofrem mais com muitas variáveis correlacionadas. A *RL 2* adiciona seleção *forward* para testar um modelo mais enxuto.

### 6.3 Ajuste de hiperparâmetros

Grid Search com **StratifiedKFold (k = 3)**, que preserva a proporção de churn em cada dobra.

| Modelo | Hiperparâmetros testados |
|---|---|
| **Regressão Logística / RL 2** | `C`: 0.01, 0.1, 1, 10 · `class_weight`: None, balanced · `solver`: liblinear, lbfgs |
| **Random Forest** | `n_estimators`: 350, 1000 · `max_depth`: 5, 15 · `min_samples_split`: 2, 15 · `min_samples_leaf`: 3, 8, 20 · `max_features`: sqrt, 0.5, None · `max_samples`: 0.5, 1.0 · `class_weight`: None, balanced |
| **Hist Gradient Boosting** | `learning_rate`: 0.03, 0.05, 0.1 · `max_iter`: 200, 400, 600 · `max_leaf_nodes`: 15, 31, 63 · `min_samples_leaf`: 10, 20, 50 · `l2_regularization`: 0.0, 0.1, 1.0 |
| **XGBoost** | `n_estimators`: 300, 600 · `learning_rate`: 0.03, 0.1 · `max_depth`: 3, 6 · `min_child_weight`: 1, 5 · `subsample`: 0.8, 1.0 · `colsample_bytree`: 0.8, 1.0 · `reg_alpha`: 0.0, 0.1 · `reg_lambda`: 1.0, 5.0 |
| **LightGBM** | `n_estimators`: 300, 600 · `learning_rate`: 0.03, 0.1 · `max_depth`: 6, 10 |
| **CatBoost** | `iterations`: 300, 600 · `learning_rate`: 0.03, 0.1 · `depth`: 4, 8 |
| **MLP Classifier** | `hidden_layer_sizes`: (64,), (128, 64) · `alpha`: 0.0001, 0.001 · `learning_rate_init`: 0.0005, 0.001 · `batch_size`: 128, 256 |

## 7. Resultados

Threshold de classificação = **0,5**. Melhor valor de cada métrica em **negrito**.

| Métrica | Reg. Logística | Reg. Logística 2 | Random Forest | Hist Gradient Boosting | XGBoost | LightGBM | CatBoost | MLP |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| test_accuracy | 0,7680 | 0,7285 | **0,7912** | 0,7749 | 0,7773 | 0,7657 | 0,7819 | 0,7773 |
| test_precision | 0,6604 | 0,5000 | **0,6901** | 0,6429 | 0,6479 | 0,5976 | 0,6667 | 0,6842 |
| test_recall | 0,2991 | **0,5897** | 0,4188 | 0,3846 | 0,3932 | 0,4188 | 0,3932 | 0,3333 |
| test_f1 | 0,4118 | **0,5412** | 0,5213 | 0,4813 | 0,4894 | 0,4925 | 0,4946 | 0,4483 |
| test_log_loss (menor é melhor) | 0,4917 | 0,5623 | **0,4640** | 0,4837 | 0,4786 | 0,4963 | 0,4749 | 0,4920 |
| test_roc_auc | 0,7602 | 0,7482 | **0,7917** | 0,7775 | 0,7796 | 0,7758 | 0,7766 | 0,7601 |
| train_roc_auc | 0,8063 | 0,8066 | 0,8655 | 0,9266 | 0,8856 | 0,9727 | 0,8863 | 0,8174 |
| oot_roc_auc | **0,8510** | 0,8467 | 0,8454 | 0,8423 | 0,8500 | 0,8300 | 0,8459 | 0,8370 |

### Leitura dos resultados

- **Random Forest** teve o melhor **AUC de teste (0,7917)**, a melhor **acurácia** e o menor **log loss**, ou seja, ordena bem e tem probabilidades mais bem calibradas.
- **LightGBM e Hist Gradient Boosting mostram overfitting claro:** AUC de treino de 0,9727 e 0,9266 contra 0,7758 e 0,7775 no teste.
- **A diferença entre as regressões logísticas** é um trade-off: a *RL 2* (com `class_weight` e seleção forward) tem o maior recall (0,59) e F1, mas sacrifica precision (0,50) e log loss.
- **Recall baixo em quase todos os modelos** (0,30 a 0,42) com threshold 0,5: os modelos "deixam passar" boa parte dos churners. Como o objetivo é ranquear, o threshold pode ser ajustado conforme a capacidade da ação de retenção.
- **O AUC no OOT ficou entre 0,83 e 0,85** para todos, mais próximo entre os modelos do que no teste, e acima do AUC de teste. *[Possível comentar aqui o motivo: composição da base OOT, sazonalidade, etc.]*

## 8. Modelo selecionado

**Random Forest**, treinado com **todas as variáveis** sobre a base **Treino + Teste (01/05/2025 a 01/05/2026)**.

| Hiperparâmetro | Valor |
|---|---|
| `n_estimators` | 1000 |
| `max_depth` | 5 |
| `min_samples_split` | 2 |
| `min_samples_leaf` | 8 |
| `max_features` | None |
| `max_samples` | 0,5 |
| `class_weight` | None |

| AUC Treino | AUC Teste | AUC OOT |
|:-:|:-:|:-:|
| 0,8655 | 0,7917 | 0,8454 |

**Por que o Random Forest?**

- Melhor desempenho no teste (AUC, acurácia e log loss) e AUC OOT competitivo (0,8454, a 0,006 do melhor).
- Gap treino × teste moderado (~0,07), bem menor que o de LightGBM, HGB e XGBoost.
- `max_depth = 5` e `max_samples = 0,5` atuam como regularização, mantendo o modelo estável.
- Não exige escala nem seleção de variáveis, o que simplifica o pipeline de produção.

*[Ajuste este trecho com a justificativa que você apresentou, se for diferente.]*

## 9. Importância das variáveis

| Variável | Importância |
|---|:-:|
| `qtFrequencia` | 0,4266 |
| `recencia` | 0,1327 |
| `freqVida` | 0,1043 |
| `diasPrimeiraTransacao` | 0,0614 |
| `saldoDia` | 0,0389 |
| `QtdeTransacoes` | 0,0237 |
| `zScore` | 0,0217 |
| `pctTransacaoTerca` | 0,0175 |
| `pctTransacaoSegunda` | 0,0155 |
| Demais variáveis | 0,1579 |

**Principais conclusões**

- **Frequência, recência e frequência de vida somam ~66%** da importância. O churn é explicado principalmente pelo *quanto e há quanto tempo* o aluno interage.
- **Todas as 9 variáveis mais importantes vêm da tabela de Pontos.** As variáveis de Cursos ficam no grupo "Demais".
- Além do comportamento recente, o **tempo de casa** (`diasPrimeiraTransacao`) e o **saldo de pontos** também contribuem.
- Aparecem **dias da semana** (terça e segunda) como sinal secundário de perfil de uso.

## 10. Predição e uso do modelo

O `predict.ipynb` carrega o modelo treinado, aplica-o à base de **01/07/2026** e gera a lista de alunos ordenada por **probabilidade de churn** (do maior para o menor risco).

Formato da saída:

| Ordem | Id Cliente | Prob. Churn |
|:-:|---|:-:|
| 1 | `<uuid do aluno>` | 0,99 |
| 2 | `<uuid do aluno>` | 0,99 |
| … | … | … |

No exemplo apresentado, os 50 alunos de maior risco têm probabilidades entre ~0,79 e ~0,99.

**Uso sugerido:** acionar campanhas de retenção de cima para baixo na lista, até o limite da capacidade da ação.

## 11. Limitações e próximos passos

**Limitações**

- **Proximidade entre target e variáveis:** o churn é definido por ausência de pontuação em 28 dias, e as variáveis mais importantes (frequência e recência) medem justamente a atividade de pontuação. Isso é esperado, mas limita o valor "descobridor" do modelo; vale acompanhar o desempenho em horizontes diferentes.
- **Recall baixo no threshold de 0,5**, apesar de bom AUC.
- **Poucas variáveis de Cursos entre as mais relevantes**, o que sugere espaço para novas features de conteúdo.

**Próximos passos possíveis**

- Calibrar o **threshold** (ou trabalhar por faixas de risco/decis) conforme o custo da ação de retenção.
- Avaliar **lift e ganho acumulado** por decil, que comunicam melhor o valor do ranking ao negócio.
- Testar **novas features** (engajamento em cursos, interações recentes, sazonalidade).
- **Monitorar** AUC e distribuição das probabilidades mês a mês (data drift) e agendar reprocessamento.
- Avaliar **calibração das probabilidades** (por exemplo, `CalibratedClassifierCV`).

## 12. Como reproduzir

*[PREENCHER conforme o seu ambiente]*

1. Clonar o repositório:
   ```bash
   git clone https://github.com/dofarias/tmw-loyalty-t5-trabalhofinal.git
   ```
2. Ambiente: Python 3 e/ou Databricks, com `pandas`, `scikit-learn`, `xgboost`, `lightgbm`, `catboost`, `matplotlib`.
3. Gerar as variáveis executando o conteúdo de `02 - Feature Store/`.
4. Executar `train.ipynb` para montar a ABT, treinar e comparar os modelos.
5. Executar `predict.ipynb` para pontuar a base mais recente.

---

*Projeto acadêmico desenvolvido para fins de aprendizado.*
