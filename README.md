# Central de Links

Página responsiva que reúne todos os repositórios públicos de **lohanrosha02-gif**.

## Abrir

- Código da página: [index.html](./index.html)
- Editar endereços compartilhados: [links.json](./links.json)

## Publicar grátis no GitHub Pages

1. Abra **Settings → Pages** neste repositório.
2. Em **Build and deployment**, escolha **Deploy from a branch**.
3. Escolha **main** e a pasta **/(root)**. Clique **Save**.
4. Depois da publicação, use **https://lohanrosha02-gif.github.io/links/**.

> O endereço acima é o padrão do GitHub Pages, mas só estará disponível após habilitar a publicação.

## Atualização automática

O site consulta a API pública do GitHub quando é aberto, quando a aba é reativada e a cada cinco minutos enquanto estiver em uso. Repositórios públicos novos são mostrados automaticamente. Links de sites publicados são identificados pela propriedade **Website/Homepage** do repositório e, quando habilitado, por GitHub Pages.

Para adicionar um site a um repositório, abra as configurações do repositório e preencha o campo **Website**, ou adicione uma entrada na propriedade `sites` de [links.json](./links.json):

```json
{
  "sites": {
    "lobi-lifestyle": "https://lobilifestyle.pages.dev/"
  },
  "links": [
    {
      "title": "Meu outro link",
      "url": "https://exemplo.com",
      "description": "Descrição opcional",
      "category": "outro"
    }
  ]
}
```

Links adicionados diretamente no botão **Adicionar link** são salvos somente no navegador atual (localStorage). Para ficarem visíveis em todos os aparelhos, copie-os para `links.json`, salve a alteração no GitHub e atualize a página. É possível exportar/importar um backup dos links locais.

A página não precisa de token nem senha de GitHub. Repositórios privados não são listados.
