from app.main import _asyncpg_connect_args


def test_strips_the_sqlalchemy_driver_and_maps_sslmode():
    dsn, kwargs = _asyncpg_connect_args("postgresql+asyncpg://u:p@h:5432/db?sslmode=require")

    assert dsn == "postgresql://u:p@h:5432/db"
    assert kwargs == {"ssl": "require"}


def test_accepts_the_ssl_spelling_written_by_the_deploy_script():
    _, kwargs = _asyncpg_connect_args("postgresql+asyncpg://u:p@h:5432/db?ssl=require")

    assert kwargs == {"ssl": "require"}


def test_disable_turns_ssl_off_instead_of_passing_a_string():
    _, kwargs = _asyncpg_connect_args("postgresql://u:p@h:5432/db?ssl=disable")

    assert kwargs == {"ssl": False}


def test_unrelated_query_parameters_survive():
    dsn, kwargs = _asyncpg_connect_args("postgresql://u:p@h:5432/db?application_name=worker")

    assert dsn == "postgresql://u:p@h:5432/db?application_name=worker"
    assert kwargs == {}
