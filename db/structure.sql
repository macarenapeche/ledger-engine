SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: assert_journal_entry_balanced(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assert_journal_entry_balanced() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  total bigint;
  cnt int;
  currencies int;
BEGIN
  SELECT COALESCE(SUM(delta), 0), COUNT(*), COUNT(DISTINCT currency)
    INTO total, cnt, currencies
    FROM postings
    WHERE journal_entry_id = NEW.journal_entry_id;

  IF cnt < 2 THEN
    RAISE EXCEPTION 'journal entry % must have at least 2 postings (has %)', NEW.journal_entry_id, cnt;
  END IF;
  IF currencies <> 1 THEN
    RAISE EXCEPTION 'journal entry % mixes currencies', NEW.journal_entry_id;
  END IF;
  IF total <> 0 THEN
    RAISE EXCEPTION 'journal entry % is unbalanced: debits - credits = %', NEW.journal_entry_id, total;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: forbid_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.forbid_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION '% on % is forbidden: the ledger is append-only', TG_OP, TG_TABLE_NAME;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    external_id character varying NOT NULL,
    holder_ref character varying NOT NULL,
    name character varying NOT NULL,
    currency character varying(3) NOT NULL,
    normal_balance character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT accounts_currency_iso CHECK (((currency)::text ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT accounts_normal_balance_valid CHECK (((normal_balance)::text = ANY ((ARRAY['debit'::character varying, 'credit'::character varying])::text[])))
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: balance_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.balance_snapshots (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    balance bigint NOT NULL,
    last_posting_id bigint NOT NULL,
    postings_count bigint NOT NULL,
    captured_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: balance_snapshots_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.balance_snapshots_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: balance_snapshots_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.balance_snapshots_id_seq OWNED BY public.balance_snapshots.id;


--
-- Name: journal_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.journal_entries (
    id bigint NOT NULL,
    description character varying NOT NULL,
    currency character varying(3) NOT NULL,
    idempotency_key character varying,
    occurred_at timestamp(6) without time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    reverses_entry_id bigint,
    originator_id bigint,
    CONSTRAINT journal_entries_currency_iso CHECK (((currency)::text ~ '^[A-Z]{3}$'::text))
);


--
-- Name: journal_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.journal_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: journal_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.journal_entries_id_seq OWNED BY public.journal_entries.id;


--
-- Name: postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.postings (
    id bigint NOT NULL,
    journal_entry_id bigint NOT NULL,
    account_id bigint NOT NULL,
    direction character varying NOT NULL,
    amount bigint NOT NULL,
    currency character varying(3) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    delta bigint GENERATED ALWAYS AS (
CASE
    WHEN ((direction)::text = 'debit'::text) THEN amount
    ELSE (- amount)
END) STORED,
    CONSTRAINT postings_amount_positive CHECK ((amount > 0)),
    CONSTRAINT postings_direction_valid CHECK (((direction)::text = ANY ((ARRAY['debit'::character varying, 'credit'::character varying])::text[])))
);


--
-- Name: postings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.postings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: postings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.postings_id_seq OWNED BY public.postings.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: balance_snapshots id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balance_snapshots ALTER COLUMN id SET DEFAULT nextval('public.balance_snapshots_id_seq'::regclass);


--
-- Name: journal_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries ALTER COLUMN id SET DEFAULT nextval('public.journal_entries_id_seq'::regclass);


--
-- Name: postings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings ALTER COLUMN id SET DEFAULT nextval('public.postings_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: balance_snapshots balance_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balance_snapshots
    ADD CONSTRAINT balance_snapshots_pkey PRIMARY KEY (id);


--
-- Name: journal_entries journal_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT journal_entries_pkey PRIMARY KEY (id);


--
-- Name: postings postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT postings_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_accounts_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_external_id ON public.accounts USING btree (external_id);


--
-- Name: index_accounts_on_holder_ref_and_currency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_holder_ref_and_currency ON public.accounts USING btree (holder_ref, currency);


--
-- Name: index_balance_snapshots_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_balance_snapshots_on_account_id ON public.balance_snapshots USING btree (account_id);


--
-- Name: index_balance_snapshots_on_account_id_and_last_posting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_balance_snapshots_on_account_id_and_last_posting_id ON public.balance_snapshots USING btree (account_id, last_posting_id);


--
-- Name: index_journal_entries_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_journal_entries_on_idempotency_key ON public.journal_entries USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);


--
-- Name: index_journal_entries_on_originator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journal_entries_on_originator_id ON public.journal_entries USING btree (originator_id);


--
-- Name: index_journal_entries_on_reverses_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_journal_entries_on_reverses_entry_id ON public.journal_entries USING btree (reverses_entry_id);


--
-- Name: index_journal_entries_one_reversal_per_entry; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_journal_entries_one_reversal_per_entry ON public.journal_entries USING btree (reverses_entry_id) WHERE (reverses_entry_id IS NOT NULL);


--
-- Name: index_postings_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_postings_on_account_id ON public.postings USING btree (account_id);


--
-- Name: index_postings_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_postings_on_account_id_and_id ON public.postings USING btree (account_id, id);


--
-- Name: index_postings_on_journal_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_postings_on_journal_entry_id ON public.postings USING btree (journal_entry_id);


--
-- Name: journal_entries journal_entries_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER journal_entries_immutable BEFORE DELETE OR UPDATE ON public.journal_entries FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();


--
-- Name: postings postings_balance_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE CONSTRAINT TRIGGER postings_balance_check AFTER INSERT ON public.postings DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION public.assert_journal_entry_balanced();


--
-- Name: postings postings_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER postings_immutable BEFORE DELETE OR UPDATE ON public.postings FOR EACH ROW EXECUTE FUNCTION public.forbid_mutation();


--
-- Name: postings fk_rails_317b87bc60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT fk_rails_317b87bc60 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: journal_entries fk_rails_5685e80cec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT fk_rails_5685e80cec FOREIGN KEY (originator_id) REFERENCES public.journal_entries(id);


--
-- Name: postings fk_rails_9e48d90554; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.postings
    ADD CONSTRAINT fk_rails_9e48d90554 FOREIGN KEY (journal_entry_id) REFERENCES public.journal_entries(id);


--
-- Name: journal_entries fk_rails_a76617785a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.journal_entries
    ADD CONSTRAINT fk_rails_a76617785a FOREIGN KEY (reverses_entry_id) REFERENCES public.journal_entries(id);


--
-- Name: balance_snapshots fk_rails_cfe2988228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.balance_snapshots
    ADD CONSTRAINT fk_rails_cfe2988228 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260625000007'),
('20260625000006'),
('20260625000005'),
('20260625000004'),
('20260625000003'),
('20260625000002'),
('20260625000001');

