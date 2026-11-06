// Protemaxi Projetos — configuração do Supabase
// A chave "publishable" é pública por natureza: a segurança fica nas regras (RLS) do banco.
// NUNCA coloque aqui a chave secreta (sb_secret_...).
window.PROTEMAXI_CONFIG = {
  supabaseUrl: "https://fpiwypqvtwzyzhvemqib.supabase.co",
  supabaseAnonKey: "sb_publishable_QDZbK3iQz5AZLmCdExiosQ_Ghj5Rh1d",
  // Conta compartilhada de visitante: entra só com o PIN, sem digitar e-mail
  visitanteEmail: "visitante@protemaxi.com.br"
};
