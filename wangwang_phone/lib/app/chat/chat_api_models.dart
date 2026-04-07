class ApiProvider {
  const ApiProvider({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.models,
  });

  final String id;
  final String label;
  final String baseUrl;
  final List<String> models;
}

const kApiProviders = <ApiProvider>[
  ApiProvider(
    id: 'deepseek',
    label: '深度求索 DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1/chat/completions',
    models: ['deepseek-chat', 'deepseek-reasoner'],
  ),
  ApiProvider(
    id: 'openai',
    label: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1/chat/completions',
    models: ['gpt-4o', 'gpt-4o-mini', 'gpt-4.1', 'gpt-4.1-mini', 'gpt-4.1-nano'],
  ),
  ApiProvider(
    id: 'claude',
    label: 'Anthropic Claude',
    baseUrl: 'https://api.anthropic.com/v1/messages',
    models: ['claude-sonnet-4-20250514', 'claude-haiku-4-5-20251001'],
  ),
  ApiProvider(
    id: 'gemini',
    label: 'Google Gemini',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    models: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'],
  ),
  ApiProvider(
    id: 'openrouter',
    label: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1/chat/completions',
    models: ['自由输入'],
  ),
];

ApiProvider? findProvider(String id) {
  for (final p in kApiProviders) {
    if (p.id == id) return p;
  }
  return null;
}
