@description('Name of the existing Azure OpenAI account.')
param azureOpenAIServiceName string

@description('Embedding deployment settings (lab defaults).')
param embeddingModelName string = 'text-embedding-ada-002'
param embeddingModelVersion string = '2'
param embeddingCapacity int = 1

@description('Chat deployment settings (must be supported in your region/account).')
param chatModelName string = 'gpt-4o-mini'
param chatModelVersion string = '2024-07-18'
param chatCapacity int = 1

// Reference the existing AOAI account
resource aoai 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: azureOpenAIServiceName
}

// 1) Create embedding deployment first
resource embedding 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: '${aoai.name}/embedding'
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

// 2) Then create chat deployment (explicitly depends on embedding)
resource chat 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: '${aoai.name}/chat'
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
  dependsOn: [
    embedding
  ]
}

output azureOpenAIEmbeddingDeploymentName string = 'embedding'
output azureOpenAIChatDeploymentName string = 'chat'
