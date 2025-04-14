--
--	DOMAINS
--

CREATE DOMAIN public.dom_dinheiro AS numeric(12,2) NOT NULL DEFAULT 0;
CREATE DOMAIN public.dom_titulo AS character varying(50) NOT NULL;

--
--	TABLES
--

CREATE TABLE IF NOT EXISTS public.usuario (
	id_usuario INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	nome public.dom_titulo NOT NULL,
	login TEXT NOT NULL,
	senha TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.balanco (
	id_balanco INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_usuario INT NOT NULL,
	mes INT NOT NULL,
	ano INT NOT NULL,
	receita public.dom_dinheiro NOT NULL DEFAULT 0,
	despesa public.dom_dinheiro NOT NULL DEFAULT 0,
	balanco public.dom_dinheiro NOT NULL DEFAULT 0,
	para_pagar public.dom_dinheiro NOT NULL DEFAULT 0,
	para_receber public.dom_dinheiro NOT NULL DEFAULT 0,
	saldo_projetado public.dom_dinheiro NOT NULL DEFAULT 0,
	saldo_atual public.dom_dinheiro NOT NULL DEFAULT 0,
	CONSTRAINT fk_usuario FOREIGN KEY (id_usuario)
		REFERENCES public.usuario (id_usuario)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT unq_balanco UNIQUE (id_usuario, mes, ano)
);

CREATE TABLE IF NOT EXISTS public.tipo_transacao (
	id_tipo_transacao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	titulo public.dom_titulo NOT NULL,
	descricao TEXT
);

CREATE TABLE IF NOT EXISTS public.categoria (
	id_categoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_usuario INT NOT NULL,
	titulo public.dom_titulo NOT NULL,
	descricao TEXT,
	CONSTRAINT fk_usuario FOREIGN KEY (id_usuario)
		REFERENCES public.usuario (id_usuario)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS public.subcategoria (
	id_subcategoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_usuario INT NOT NULL,
	id_categoria INT NOT NULL,
	titulo public.dom_titulo NOT NULL,
	CONSTRAINT fk_usuario FOREIGN KEY (id_usuario)
		REFERENCES public.usuario (id_usuario)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_categoria FOREIGN KEY (id_categoria)
		REFERENCES public.categoria (id_categoria)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS public.conta_bancaria (
	id_conta_bancaria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_usuario INT NOT NULL,
	titulo public.dom_titulo NOT NULL,
	saldo public.dom_dinheiro NOT NULL DEFAULT 0,
	contabilizar_saldo BOOLEAN NOT NULL DEFAULT TRUE,
	ativo BOOLEAN NOT NULL DEFAULT TRUE,
	ultima_atualizacao TIMESTAMP NOT NULL DEFAULT now(),
	data_criacao TIMESTAMP NOT NULL DEFAULT now(),
	credito BOOLEAN NOT NULL DEFAULT FALSE,
	limite_total public.dom_dinheiro NOT NULL DEFAULT 0,
	limite_utilizado public.dom_dinheiro NOT NULL DEFAULT 0,
	dia_fechamento INT,
	dia_vencimento INT,
	CONSTRAINT fk_usuario FOREIGN KEY (id_usuario)
		REFERENCES public.usuario (id_usuario)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT chk_credito_conta CHECK (NOT credito OR (limite_total > 0 AND dia_fechamento IS NOT NULL AND dia_vencimento IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.fatura (
	id_fatura INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_conta_bancaria INT NOT NULL,
	mes INT NOT NULL,
	ano INT NOT NULL,
	valor public.dom_dinheiro NOT NULL DEFAULT 0,
	valor_pago public.dom_dinheiro NOT NULL DEFAULT 0,
	paga BOOLEAN NOT NULL DEFAULT FALSE,
	ultimo_pagamento TIMESTAMP,
	ultima_atualizacao TIMESTAMP NOT NULL DEFAULT now(),
	data_criacao TIMESTAMP NOT NULL DEFAULT now(),
	CONSTRAINT fk_conta_bancaria FOREIGN KEY (id_conta_bancaria)
		REFERENCES public.conta_bancaria (id_conta_bancaria)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT unq_fatura UNIQUE (id_conta_bancaria, mes, ano)
);

CREATE TABLE IF NOT EXISTS public.transacao (
	id_transacao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_conta_bancaria INT NOT NULL,
	id_tipo_transacao INT NOT NULL,
	id_subcategoria INT NOT NULL,
	descricao TEXT,
	credito BOOLEAN NOT NULL DEFAULT FALSE,
	parcelas INT,
	valor public.dom_dinheiro NOT NULL DEFAULT 0,
	data_marcada TIMESTAMP,
	data_criacao TIMESTAMP NOT NULL DEFAULT now(),
	divisao_parcelas public.dom_dinheiro[],
	contemplada BOOLEAN NOT NULL DEFAULT FALSE,
	CONSTRAINT fk_tipo_transacao FOREIGN KEY (id_tipo_transacao)
		REFERENCES public.tipo_transacao (id_tipo_transacao)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_subcategoria FOREIGN KEY (id_subcategoria)
		REFERENCES public.subcategoria (id_subcategoria)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_conta_bancaria FOREIGN KEY (id_conta_bancaria)
		REFERENCES public.conta_bancaria (id_conta_bancaria)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT chk_valor_transacao CHECK (valor > 0),
	CONSTRAINT chk_credito_transacao CHECK (NOT credito OR (divisao_parcelas IS NOT NULL AND parcelas >= 1 AND array_length(divisao_parcelas, 1) = parcelas))
);

CREATE TABLE IF NOT EXISTS public.item_fatura (
	id_item_fatura INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_fatura INT NOT NULL,
	id_transacao INT NOT NULL,
	parcela_atual INT NOT NULL DEFAULT 1,
	parcela_total INT NOT NULL DEFAULT 1,
	valor public.dom_dinheiro NOT NULL,
	CONSTRAINT fk_fatura FOREIGN KEY (id_fatura)
		REFERENCES public.fatura (id_fatura)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_transacao FOREIGN KEY (id_transacao)
		REFERENCES public.transacao (id_transacao)
		ON DELETE CASCADE
		ON UPDATE CASCADE
);

CREATE TABLE IF NOT EXISTS public.subconta (
	id_conta_bancaria INT NOT NULL,
	id_subconta INT,
	titulo public.dom_titulo NOT NULL,
	saldo public.dom_dinheiro NOT NULL DEFAULT 0,
	ativo BOOLEAN NOT NULL DEFAULT TRUE,
	contabilizar_saldo BOOLEAN NOT NULL DEFAULT TRUE,
	data_criacao TIMESTAMP NOT NULL DEFAULT now(),
	PRIMARY KEY (id_subconta, id_conta_bancaria),
	CONSTRAINT fk_conta_bancaria FOREIGN KEY (id_conta_bancaria)
		REFERENCES public.conta_bancaria (id_conta_bancaria)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT chk_subconta_saldo CHECK (saldo >= 0)
);

CREATE TABLE IF NOT EXISTS public.transferencia (
	id_transferencia INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	id_conta_origem INT NOT NULL,
	id_subconta_origem INT NOT NULL,
	id_conta_destino INT NOT NULL,
	id_subconta_destino INT NOT NULL,
	valor public.dom_dinheiro NOT NULL DEFAULT 0,
	descricao TEXT,
	data_transferencia TIMESTAMP NOT NULL DEFAULT now(),
	CONSTRAINT fk_subconta_origem FOREIGN KEY (id_conta_origem, id_subconta_origem)
		REFERENCES public.subconta (id_conta_bancaria, id_subconta)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT fk_subconta_destino FOREIGN KEY (id_conta_destino, id_subconta_destino)
		REFERENCES public.subconta (id_conta_bancaria, id_subconta)
		ON DELETE CASCADE
		ON UPDATE CASCADE,
	CONSTRAINT chk_valor_transferencia CHECK (valor > 0)
);

--
--	INDEXES
--

CREATE INDEX IF NOT EXISTS idx_balanco_id_usuario ON public.balanco (id_usuario);

CREATE INDEX IF NOT EXISTS idx_categoria_id_usuario ON public.categoria (id_usuario);

CREATE INDEX IF NOT EXISTS idx_subcategoria_id_usuario ON public.subcategoria (id_usuario);

CREATE INDEX IF NOT EXISTS idx_subcategoria_id_categoria ON public.subcategoria (id_categoria);

CREATE INDEX IF NOT EXISTS idx_conta_bancaria_id_usuario ON public.conta_bancaria (id_usuario);

CREATE INDEX IF NOT EXISTS idx_fatura_id_conta_bancaria ON public.fatura (id_conta_bancaria);

CREATE INDEX IF NOT EXISTS idx_transacao_id_conta_bancaria ON public.transacao (id_conta_bancaria);

CREATE INDEX IF NOT EXISTS idx_transacao_id_tipo_transacao ON public.transacao (id_tipo_transacao);

CREATE INDEX IF NOT EXISTS idx_transacao_id_subcategoria ON public.transacao (id_subcategoria);

CREATE INDEX IF NOT EXISTS idx_item_fatura_id_fatura ON public.item_fatura (id_fatura);

CREATE INDEX IF NOT EXISTS idx_item_fatura_id_transacao ON public.item_fatura (id_transacao);

CREATE INDEX IF NOT EXISTS idx_subconta_id_conta_bancaria ON public.subconta (id_conta_bancaria);

CREATE INDEX IF NOT EXISTS idx_transferencia_origem ON public.transferencia (id_conta_origem, id_subconta_origem);

CREATE INDEX IF NOT EXISTS idx_transferencia_destino ON public.transferencia (id_conta_destino, id_subconta_destino);
