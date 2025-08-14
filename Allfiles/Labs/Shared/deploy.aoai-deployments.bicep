@description('Location (not strictly required for existing, kept for clarity).')
param location string = resourceGroup().location

@description('Name of the existing Azure OpenAI account to attach deployments to.')
param azureOpenAIServiceName string

@description('Embedding model name and version.')
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingModelVersion string = '2'
@description('Embedding deployment capacity (small for labs).')
param embeddingCapacity int = 1

@description('Chat model name and version (must be available in your region).')
param chatModelName string = 'gpt-4o-mini'
param chatModelVersion string = '2024-07-18'
@description('Chat deployment capacity (small for labs).')
param chatCapacity int = 1

// Reference the existing AOAI account as the parent
resource aoai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: azureOpenAIServiceName
}

// Embedding deployment
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

// Chat deployment
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
