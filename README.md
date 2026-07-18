# MemoShot

> **Capturou, organizou.**

MemoShot é um organizador automático e local de screenshots para Android. Após
as permissões iniciais, a visão do produto é detectar novas capturas,
compreender seu conteúdo com processamento no aparelho e organizá-las em pastas
inteligentes. O usuário intervém principalmente quando a classificação é
incerta.

O aplicativo funciona offline, sem backend obrigatório e sem serviços pagos.
Screenshots e texto reconhecido não são enviados para serviços externos. As
pastas são relações lógicas: o mesmo arquivo pode aparecer em várias
visualizações sem ser duplicado.

## Estado do projeto

Já estão implementados importação e armazenamento local, detecção automática no
Android, inbox durável com WorkManager, OCR pelo pipeline Flutter, pesquisa,
categorias, etiquetas e um motor lexical local de classificação.

O fluxo automático completo ainda não está pronto: o processamento ainda depende
da execução do aplicativo, e as sugestões de classificação ainda não são
persistidas nem aplicadas. Pastas inteligentes hierárquicas, revisão de casos
incertos, notificações acionáveis e execução integral em segundo plano fazem
parte das próximas fases.

## Privacidade

- processamento local por padrão;
- nenhum envio de screenshots sem consentimento;
- nenhum OCR completo ou conteúdo sensível em logs;
- notificações futuras sem informações sensíveis;
- nenhum arquivo original excluído automaticamente.

## Requisitos

- Flutter compatível com Dart 3.12 ou superior;
- Android SDK;
- dispositivo ou emulador Android configurado.

## Executar o projeto

```bash
flutter pub get
flutter run
```

## Verificações

```bash
dart format .
flutter analyze
flutter test
```

## Documentação

O `README.md` é a documentação pública versionada nesta etapa. Instruções de
agentes, contexto operacional, prompts e notas do ambiente permanecem locais e
não fazem parte do repositório.

## Nota de migração

MemoShot foi anteriormente chamado **Contexto**. O package Dart atual é
`memoshot`, e a identidade Android é `br.com.jeffersont.memoshot`. A troca do
identificador Android cria um novo sandbox: uma instalação antiga do Contexto
permanece separada até ser desinstalada, sem migração automática de dados.
