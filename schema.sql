CREATE TABLE lists(
  id serial PRIMARY KEY,
  name varchar(50) UNIQUE NOT NULL
);


CREATE TABLE todo (
  id serial PRIMARY KEY,
  list_id integer REFERENCES lists(id) NOT NULL,
  name VARCHAR(50) NOT NULL,
  completed boolean DEFAULT false NOT NULL
);