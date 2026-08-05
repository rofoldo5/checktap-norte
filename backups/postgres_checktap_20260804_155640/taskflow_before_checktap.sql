--
-- PostgreSQL database dump
--

\restrict iHaXlde7cHJUDTXk2aTu1qKOg2R2mhfsSFDjc8RBaw8Mkng2klhW2svm3PbZXza

-- Dumped from database version 17.10
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid NOT NULL,
    title character varying(150) NOT NULL,
    description text,
    status character varying(20) NOT NULL,
    priority character varying(10) NOT NULL,
    created_by_id uuid NOT NULL,
    assigned_to_id uuid,
    completed_by_id uuid,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    name character varying(120) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    is_admin boolean NOT NULL,
    is_active boolean NOT NULL,
    created_at timestamp with time zone NOT NULL
);


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.alembic_version (version_num) FROM stdin;
0001_initial
\.


--
-- Data for Name: tasks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.tasks (id, title, description, status, priority, created_by_id, assigned_to_id, completed_by_id, created_at, updated_at, completed_at) FROM stdin;
f176009e-db44-49a6-9942-04d8e8a8eeef	aaàaàaa	\N	PENDIENTE	MEDIA	7867f860-b62b-4205-b5e7-4963edae3302	\N	\N	2026-08-04 19:36:10.219002+00	2026-08-04 19:36:10.219005+00	\N
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, name, email, password_hash, is_admin, is_active, created_at) FROM stdin;
7867f860-b62b-4205-b5e7-4963edae3302	Administrador	admin@taskflow.com	$argon2id$v=19$m=65536,t=3,p=4$QN8Q3ykeNPFqbAwDk6x0AA$5sfYNdUWekQGqsvCrIT+i/QXcCPs+hucIh88TbZWVio	t	t	2026-08-04 19:14:49.965522+00
4e980d86-c3d4-4dd2-b0ab-97ea61486d1d	Administrador	admin.legacy@taskflow.com	$argon2id$v=19$m=65536,t=3,p=4$7p8KicxsEWifQ64noW0xww$r/0XkaY21yS8et9ES+Gb0UWBRRRauCiJXd7rqk2wFgs	t	t	2026-08-04 19:03:32.343754+00
\.


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: ix_tasks_assigned_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_assigned_to_id ON public.tasks USING btree (assigned_to_id);


--
-- Name: ix_tasks_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_completed_at ON public.tasks USING btree (completed_at);


--
-- Name: ix_tasks_completed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_completed_by_id ON public.tasks USING btree (completed_by_id);


--
-- Name: ix_tasks_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_created_at ON public.tasks USING btree (created_at);


--
-- Name: ix_tasks_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_created_by_id ON public.tasks USING btree (created_by_id);


--
-- Name: ix_tasks_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_priority ON public.tasks USING btree (priority);


--
-- Name: ix_tasks_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_tasks_status ON public.tasks USING btree (status);


--
-- Name: ix_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ix_users_email ON public.users USING btree (email);


--
-- Name: tasks tasks_assigned_to_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_assigned_to_id_fkey FOREIGN KEY (assigned_to_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_completed_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_completed_by_id_fkey FOREIGN KEY (completed_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: tasks tasks_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict iHaXlde7cHJUDTXk2aTu1qKOg2R2mhfsSFDjc8RBaw8Mkng2klhW2svm3PbZXza

