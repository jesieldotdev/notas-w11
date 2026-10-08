# notas-w11

As **Notas Autoadesivas do Windows 11** no **KDE Plasma 6**, sincronizadas com o
**Google Keep** — no celular, é só usar o app do Keep (e os widgets dele).

Parte do [plasma-w11](https://github.com/jesieldotdev/plasma-w11).

- **Notas autoadesivas**: cada nota é uma janelinha de vidro na cor dela, com a barra do
  Windows (＋ nova, ⋯ cores/lista/excluir, × fechar) que vira uma faixa fina sem foco;
  texto ou lista de tarefas, fixar, posição lembrada; as notas abertas reabrem no login.
- **Lista "Notas Autoadesivas"**: painel de vidro (desfoque do KWin) com pesquisa e os
  cartões das notas.
- **Google Keep**: tudo vai para o Keep (cores, fixadas, listas); o que muda no celular
  chega em instantes. Cópia local completa: abre na hora e funciona sem internet.
- **Entrar com o Google**: um clique; a página de login do próprio Google conecta sozinha.
  O acesso fica no KWallet.
- **Widget do Plasma** para o painel e a área de trabalho, e o painel de notas no relógio
  do plasma-w11 (escreve direto nele).

> A sincronia usa a [gkeepapi](https://github.com/kiwiz/gkeepapi), biblioteca **não oficial**
> (a API oficial do Keep é só para contas Google Workspace). Se um dia o Google mudar algo,
> as notas continuam na cópia local.

## Instalar

```sh
git clone https://github.com/jesieldotdev/notas-w11
cd notas-w11
./install.sh
```

Depois abra **Notas Autoadesivas** pelo menu e clique em **Entrar com o Google**.

Pela linha de comando: `notas-w11` (lista), `notas-w11 --new` (nota nova),
`notas-w11 --open ID`.

## Desinstalar

```sh
./uninstall.sh          # remove o app (as notas continuam no Keep e na cópia local)
./uninstall.sh --purge  # remove também a cópia local e o acesso salvo
```

## Licença

GPL-2.0-or-later.
