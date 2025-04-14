--
--	FUNCTIONS
--

CREATE OR REPLACE FUNCTION public.fn_set_id_subconta()
RETURNS TRIGGER AS $$
DECLARE
	ultimo_id INT;
BEGIN
	SELECT COALESCE(MAX(id_subconta), 0) INTO ultimo_id FROM public.subconta WHERE id_conta_bancaria = NEW.id_conta_bancaria;
	NEW.id_subconta := ultimo_id + 1;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_cria_subconta()
RETURNS TRIGGER AS $$
BEGIN
	INSERT INTO public.subconta (id_conta_bancaria, titulo, saldo) VALUES (NEW.id_conta_bancaria, 'Conta Corrente', NEW.saldo);
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_update_saldo_conta_bancaria()
RETURNS TRIGGER AS $$
DECLARE
	novo_saldo public.dom_dinheiro := 0;
	conta_id INT;
BEGIN
	IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN conta_id := NEW.id_conta_bancaria;
	ELSIF TG_OP = 'DELETE' THEN conta_id := OLD.id_conta_bancaria;
	END IF;
	SELECT COALESCE(SUM(saldo), 0) INTO novo_saldo FROM public.subconta WHERE id_conta_bancaria = conta_id AND contabilizar_saldo = TRUE;
	UPDATE public.conta_bancaria SET saldo = novo_saldo, ultima_atualizacao = NOW() WHERE id_conta_bancaria = conta_id;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_transferencia()
RETURNS TRIGGER AS $$
DECLARE
	v_source_balance public.dom_dinheiro := 0;
	v_dest_balance   public.dom_dinheiro := 0;
BEGIN
	IF TG_OP = 'INSERT' THEN
		SELECT saldo INTO v_source_balance FROM public.subconta WHERE id_conta_bancaria = NEW.id_conta_origem AND id_subconta = NEW.id_subconta_origem;

		IF v_source_balance < NEW.valor THEN
			RAISE EXCEPTION 'Saldo insuficiente para tranferência. Saldo atual: %, necessário: %', v_source_balance, NEW.valor;
		END IF;

		UPDATE public.subconta SET saldo = saldo - NEW.valor WHERE id_conta_bancaria = NEW.id_conta_origem AND id_subconta = NEW.id_subconta_origem;

		UPDATE public.subconta SET saldo = saldo + NEW.valor WHERE id_conta_bancaria = NEW.id_conta_destino AND id_subconta = NEW.id_subconta_destino;

		RETURN NEW;
	ELSIF TG_OP = 'DELETE' THEN
		SELECT saldo INTO v_dest_balance FROM public.subconta WHERE id_conta_bancaria = OLD.id_conta_destino AND id_subconta = OLD.id_subconta_destino;

		IF v_dest_balance < OLD.valor THEN
			RAISE EXCEPTION 'Saldo insuficiente para reintegração. Saldo atual: %, necessário: %', v_dest_balance, OLD.valor;
		END IF;

		UPDATE public.subconta SET saldo = saldo - OLD.valor WHERE id_conta_bancaria = OLD.id_conta_destino AND id_subconta = OLD.id_subconta_destino;

		UPDATE public.subconta SET saldo = saldo + OLD.valor WHERE id_conta_bancaria = OLD.id_conta_origem AND id_subconta = OLD.id_subconta_origem;

		RETURN OLD;
	END IF;

	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_insert_transacao()
RETURNS TRIGGER AS $$
DECLARE
	conta RECORD;
	data_marcada DATE;
	id_fatura_parcela INT;
	mes_parcela INT;
	ano_parcela INT;
BEGIN
	SELECT * INTO conta FROM conta_bancaria WHERE id_conta_bancaria = NEW.id_conta_bancaria;
	data_marcada := COALESCE(NEW.data_marcada, NOW());

	IF NEW.id_tipo_transacao = 1 THEN
		IF NEW.credito THEN
			IF NOT conta.credito THEN
				RAISE EXCEPTION 'A conta bancaria não realiza transações de crédito';
			END IF;

			IF (conta.limite_total - conta.limite_utilizado) < NEW.valor THEN
				RAISE EXCEPTION 'Limite insuficiente para prosseguir com a transação';
			END IF;

			mes_parcela := EXTRACT(MONTH FROM data_marcada) - 1;
			ano_parcela := EXTRACT(YEAR FROM data_marcada);

			-- validação se já passou do fechamento
			IF EXTRACT(DAY FROM data_marcada) >= conta.dia_fechamento THEN
				IF mes_parcela = 11 THEN
					mes_parcela := 0;
					ano_parcela := ano_parcela + 1;
				ELSE
					mes_parcela := mes_parcela + 1;
				END IF;
			END IF;

			FOR i IN 1..NEW.parcelas LOOP
				-- criar a fatura ou atualizar se houver
				INSERT INTO fatura (id_conta_bancaria, mes, ano, valor) VALUES (NEW.id_conta_bancaria, mes_parcela, ano_parcela, NEW.divisao_parcelas[i])
				ON CONFLICT (id_conta_bancaria, mes, ano) DO UPDATE SET valor = fatura.valor + EXCLUDED.valor, ultima_atualizacao = NOW();

				SELECT id_fatura INTO id_fatura_parcela FROM fatura WHERE id_conta_bancaria = NEW.id_conta_bancaria AND mes = mes_parcela AND ano = ano_parcela;

				-- confere se o dia do vencimento é no mesmo mês que o dia do fechamento e cria um balanço ou atualiza se já houver
				IF conta.dia_vencimento > conta.dia_fechamento THEN
					INSERT INTO balanco (id_usuario, mes, ano, para_pagar) VALUES (conta.id_usuario, mes_parcela, ano_parcela, NEW.divisao_parcelas[i])
					ON CONFLICT (id_usuario, mes, ano) DO UPDATE SET para_pagar = balanco.para_pagar + EXCLUDED.para_pagar;
				ELSE
					INSERT INTO balanco (id_usuario, mes, ano, para_pagar) VALUES (conta.id_usuario, CASE WHEN mes_parcela = 11 THEN 0 ELSE mes_parcela + 1 END, CASE WHEN mes_parcela = 11 THEN ano_parcela + 1 ELSE ano_parcela END, NEW.divisao_parcelas[i])
					ON CONFLICT (id_usuario, mes, ano) DO UPDATE SET para_pagar = balanco.para_pagar + EXCLUDED.para_pagar;
				END IF;

				INSERT INTO item_fatura (id_fatura, id_transacao, parcela_atual, parcela_total, valor) VALUES (id_fatura_parcela, NEW.id_transacao, i, NEW.parcelas, NEW.divisao_parcelas[i]);
				
				IF mes_parcela = 11 THEN
					mes_parcela := 0;
					ano_parcela := ano_parcela + 1;
				ELSE
					mes_parcela := mes_parcela + 1;
				END IF;
			END LOOP;

			UPDATE conta_bancaria SET limite_utilizado = limite_utilizado + NEW.valor, ultima_atualizacao = NOW() WHERE id_conta_bancaria = NEW.id_conta_bancaria;
		ELSE
			IF NEW.contemplada THEN
				IF (SELECT saldo FROM subconta WHERE id_conta_bancaria = NEW.id_conta_bancaria AND id_subconta = 1) < NEW.valor THEN
					RAISE EXCEPTION 'Saldo insuficiente na conta corrente';
				END IF;

				UPDATE subconta SET saldo = saldo - NEW.valor WHERE id_conta_bancaria = NEW.id_conta_bancaria AND id_subconta = 1;

				IF conta.contabilizar_saldo THEN
					INSERT INTO balanco (id_usuario, mes, ano, despesa) VALUES (conta.id_usuario, EXTRACT(MONTH FROM data_marcada) - 1, EXTRACT(YEAR FROM data_marcada), NEW.valor)
					ON CONFLICT (id_usuario, mes, ano) DO UPDATE SET despesa = balanco.despesa + EXCLUDED.despesa;
				END IF;
			ELSIF NEW.data_marcada IS NOT NULL AND conta.contabilizar_saldo THEN
				INSERT INTO balanco (id_usuario, mes, ano, para_pagar) VALUES (conta.id_usuario, EXTRACT(MONTH FROM NEW.data_marcada) - 1, EXTRACT(YEAR FROM NEW.data_marcada), NEW.valor)
				ON CONFLICT (id_usuario, mes, ano) DO UPDATE SET para_pagar = balanco.para_pagar + EXCLUDED.para_pagar;
			END IF;
		END IF;
	ELSIF NEW.id_tipo_transacao = 2 THEN
		IF NEW.contemplada THEN
			UPDATE subconta SET saldo = saldo + NEW.valor WHERE id_conta_bancaria = NEW.id_conta_bancaria AND id_subconta = 1;

			IF conta.contabilizar_saldo THEN
				INSERT INTO balanco (id_usuario, mes, ano, receita) VALUES (conta.id_usuario, EXTRACT(MONTH FROM data_marcada) - 1, EXTRACT(YEAR FROM data_marcada), NEW.valor)
				ON CONFLICT (id_usuario, mes, ano) DO UPDATE SET receita = balanco.receita + EXCLUDED.receita;
			END IF;
		ELSIF NEW.data_marcada IS NOT NULL AND conta.contabilizar_saldo THEN
			INSERT INTO balanco (id_usuario, mes, ano, para_receber) VALUES (conta.id_usuario, EXTRACT(MONTH FROM NEW.data_marcada) - 1, EXTRACT(YEAR FROM NEW.data_marcada), NEW.valor)
			ON CONFLICT (id_usuario, mes, ano) DO UPDATE SET para_receber = balanco.para_receber + EXCLUDED.para_receber;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_update_transacao()
RETURNS TRIGGER AS $$
DECLARE
	conta RECORD;
BEGIN
	IF NEW.contemplada AND NOT OLD.contemplada THEN
		SELECT * INTO conta FROM conta_bancaria WHERE id_conta_bancaria = NEW.id_conta_bancaria;

		IF NEW.id_tipo_transacao = 1 THEN
			IF (SELECT saldo FROM subconta WHERE id_conta_bancaria = NEW.id_conta_bancaria AND id_subconta = 1) < NEW.valor THEN
				RAISE EXCEPTION 'Saldo insuficiente na conta corrente';
			END IF;

			UPDATE subconta SET saldo = saldo - NEW.valor WHERE id_conta_bancaria = NEW.id_conta_bancaria AND id_subconta = 1;

			IF conta.contabilizar_saldo THEN
				UPDATE balanco SET para_pagar = para_pagar - NEW.valor, despesa = despesa + NEW.valor WHERE id_usuario = conta.id_usuario AND mes = EXTRACT(MONTH FROM NEW.data_marcada) - 1 AND ano = EXTRACT(YEAR FROM NEW.data_marcada);
			END IF;
		ELSIF NEW.id_tipo_transacao = 2 THEN
			UPDATE subconta SET saldo = saldo + NEW.valor WHERE id_conta_bancaria = NEW.id_conta_bancaria AND id_subconta = 1;

			IF conta.contabilizar_saldo THEN
				UPDATE balanco SET para_receber = para_receber - NEW.valor, receita = receita + NEW.valor WHERE id_usuario = conta.id_usuario AND mes = EXTRACT(MONTH FROM NEW.data_marcada) - 1 AND ano = EXTRACT(YEAR FROM NEW.data_marcada);
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_balanco()
RETURNS TRIGGER AS $$
DECLARE
	saldo_total NUMERIC;
BEGIN
	NEW.balanco := NEW.receita - NEW.despesa;
	SELECT COALESCE(SUM(saldo), 0) INTO saldo_total FROM public.conta_bancaria WHERE id_usuario = NEW.id_usuario AND contabilizar_saldo = TRUE;
	NEW.saldo_projetado := saldo_total + NEW.para_receber - NEW.para_pagar;
	NEW.saldo_atual := saldo_total;
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION public.fn_fatura()
RETURNS TRIGGER AS $$
DECLARE
	conta RECORD;
	mes_pagamento INT;
	ano_pagamento INT;
	descricao TEXT;
BEGIN
	IF NEW.valor_pago != OLD.valor_pago THEN
		SELECT * INTO conta FROM conta_bancaria WHERE id_conta_bancaria = NEW.id_conta_bancaria;
		mes_pagamento := EXTRACT(MONTH FROM NEW.ultimo_pagamento) - 1;
		ano_pagamento := EXTRACT(YEAR FROM NEW.ultimo_pagamento);
		descricao := 'Pagamento da Fatura %%/%', CASE WHEN mes_pagamento < 9 THEN '0' ELSE '' END, mes_pagamento + 1, ano_pagamento;
	
		INSERT INTO public.transacao (id_conta_bancaria, id_tipo_transacao, id_subcategoria, descricao, credito, valor, data_marcada, contemplada) VALUES
		(NEW.id_conta_bancaria, 1, 103, descricao, FALSE, NEW.valor_pago - OLD.valor_pago, NEW.ultimo_pagamento, TRUE);

		IF NEW.valor_pago = NEW.valor THEN
			NEW.paga := TRUE;
		END IF;

		IF conta.dia_vencimento > conta.dia_fechamento THEN
			UPDATE balanco SET para_pagar = para_pagar - NEW.valor_pago - OLD.valor_pago, despesa = despesa + NEW.valor_pago - OLD.valor_pago WHERE id_usuario = conta.id_usuario AND mes = mes_pagamento AND ano = ano_pagamento;
		ELSE
			UPDATE balanco SET para_pagar = para_pagar - NEW.valor_pago - OLD.valor_pago, despesa = despesa + NEW.valor_pago - OLD.valor_pago WHERE id_usuario = conta.id_usuario AND mes = CASE WHEN mes_pagamento = 11 THEN 0 ELSE mes_pagamento + 1 END AND ano = CASE WHEN mes_pagamento = 11 THEN ano_parcela + 1 ELSE ano_parcela END;
		END IF;
	END IF;

	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--
--  TRIGGERS
--

CREATE TRIGGER trg_id_subconta BEFORE INSERT ON public.subconta FOR EACH ROW EXECUTE FUNCTION public.fn_set_id_subconta();

CREATE TRIGGER trg_subconta_conta_bancaria AFTER INSERT ON public.conta_bancaria FOR EACH ROW EXECUTE PROCEDURE public.fn_cria_subconta();

CREATE TRIGGER trg_update_saldo_conta_bancaria AFTER INSERT OR UPDATE OR DELETE ON public.subconta FOR EACH ROW EXECUTE FUNCTION public.fn_update_saldo_conta_bancaria();

CREATE TRIGGER trg_transferencia BEFORE INSERT OR DELETE ON public.transferencia FOR EACH ROW EXECUTE FUNCTION public.fn_transferencia();

CREATE TRIGGER trg_insert_transacao AFTER INSERT ON transacao FOR EACH ROW EXECUTE FUNCTION public.fn_insert_transacao();

CREATE TRIGGER trg_update_transacao AFTER UPDATE ON transacao FOR EACH ROW EXECUTE FUNCTION public.fn_update_transacao();

CREATE TRIGGER trg_balanco BEFORE INSERT OR UPDATE ON public.balanco FOR EACH ROW EXECUTE FUNCTION public.fn_balanco();

CREATE TRIGGER trg_fatura BEFORE UPDATE ON public.fatura FOR EACH ROW EXECUTE FUNCTION public.fn_fatura();
