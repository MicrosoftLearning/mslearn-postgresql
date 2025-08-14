@description('Name of the existing Azure OpenAI account.')
param azureOpenAIServiceName string

@description('Embedding model to deploy.')
param embeddingModelName string = 'text-embedding-ada-002'

@description('Embedding model version.')
param embeddingModelVersion string = '2'

@description('Capacity for embedding deployment (keep small for labs).')
param embeddingCapacity int = 1

@description('Chat model to deploy.')
param chatModelName string = 'gpt-4o-mini'

@description('Chat model version.')
param chatModelVersion string = '2024-07-18'

@description('Capacity for chat deployment (keep small for labs).')
param chatCapacity int = 1

// Reference the existing AOAI account (the parent)
resource aoai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: azureOpenAIServiceName
}

// Child deployment: Embeddings (uses the parent property)
resource embedding 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'embedding'
  parent: aoai
  sku: {
    name: 'Standard'
    capacity: embeddingCapacity
  }
  properties: {
    model: {
      name: embeddingModelName
      version: embeddingModelVersion
      format: 'OpenAI'
    }
  }
}

// Child deployment: Chat (uses the parent property)
resource chat 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'chat'
  parent: aoai
  sku: {
    name: 'Standard'
    capacity: chatCapacity
  }
  properties: {
    model: {
      name: chatModelName
      version: chatModelVersion
      format: 'OpenAI'
    }
  }
}

output azureOpenAIEmbeddingDeploymentName string = embedding.name
output azureOpenAIChatDeploymentName string = chat.name
