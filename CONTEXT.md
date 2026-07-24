# Notinhas Visual Handoff Context

This context defines the vocabulary for the Notinhas capture-to-annotate handoff flow.

## Language

**Notinha visual**:
Uma marcação numerada associada a um ponto ou área da imagem e a um comentário textual.
_Avoid_: anotação de texto genérica, comentário isolado

**Caixa contextual de edição**:
A interface temporária que edita o comentário e os controles visuais da Notinha visual ativa.
_Avoid_: painel lateral, painel de resumo

**Painel lateral de resumo**:
A lista persistente na janela do editor que reúne as Notinhas visuais existentes e oferece ações sobre elas.
_Avoid_: caixa de comentários, editor de comentários

**Área útil do editor**:
O espaço disponível para editar a imagem, incluindo o canvas e o fundo/padding, mas excluindo toolbar, barra de propriedades, barra inferior e painel lateral.
_Avoid_: janela inteira, área da imagem

## Capture session chrome

**Capture Markup**:
O fluxo de captura com marcação ao vivo sobre a área selecionada, sem abrir o editor de imagens completo.
_Avoid_: All-in-One, anotar depois no editor

**All-in-One**:
O fluxo único de captura que escolhe o modo (área, anotar, OCR, etc.) e refina a seleção com barras flutuantes separadas.
_Avoid_: Capture Markup, seletor genérico de modo

**Barra flutuante de captura (HUD)**:
Painel borderless separado (fora do overlay de seleção) que hospeda controles durante All-in-One ou recording.
_Avoid_: chrome inline de captura, toolbar do editor Annotate

**Chrome inline de captura**:
Controles de ferramenta desenhados dentro do mesmo painel fullscreen do Capture Markup.
_Avoid_: barra flutuante de captura (HUD), CaptureFloatingHUDWindow

**Chrome de seleção compartilhado**:
Métricas, geometria e desenho dos handles em L, hit-tests, cursores de redimensionamento e contraste visual da área selecionada, reutilizados por All-in-One/Recording e Capture Markup.
_Avoid_: host de overlay unificado, aspect lock, snapping, ferramentas de anotar

**Contrato de seleção compartilhado**:
Comportamento comum de uma área já selecionada: criação/ajuste visual, redimensionamento, movimento, limites mínimos, resposta de cursor e ajuste magnético (snapping). Cada host preserva suas próprias regras de sessão, anotação, gravação e controles.
_Avoid_: máquina de estados única, host de seleção unificado

**Ajuste magnético compartilhado (snapping)**:
Correção comum da área selecionada em direção a limites relevantes — visuais, semânticos ou de tela — com a mesma expectativa de sensibilidade e previsibilidade. A disponibilidade de cada tipo de limite pode variar por host; isso não muda o contrato do ajuste.
_Avoid_: aspect lock, crop automático

**Sensibilidade do ajuste magnético**:
Resposta do snapping a transições de cor ou luminância na imagem. É distinta do contraste visual usado para manter handles, bordas e cursores legíveis.
_Avoid_: contraste do chrome, cor do handle

**Contrato da barra flutuante de captura**:
Regra comum para barras de captura separadas do overlay: mesma prioridade de camada, hit-testing determinístico, cursor de seta sobre os controles e preservação do foco do aplicativo capturado.
_Avoid_: chrome inline de captura, toolbar do editor Annotate

**Host de seleção**:
O painel/sessão que apresenta a seleção (ex.: `RecordingRegionOverlayWindow` ou `InlineAreaAnnotate*`), incluindo política de sessão além do chrome visual.
_Avoid_: chrome de seleção compartilhado
