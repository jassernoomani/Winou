"""Migrations: `alembic upgrade head`. New migration: `alembic revision --autogenerate -m "..."`."""
from alembic import context
from geoalchemy2 import alembic_helpers
from sqlalchemy import create_engine

from app.config import settings
from app.models import Base

def include_object(obj, name, type_, reflected, compare_to):
    # The PostGIS image ships its own tables (spatial_ref_sys, Tiger geocoder...): only manage ours
    table = obj if type_ == "table" else getattr(obj, "table", None)
    if reflected and table is not None and table.name not in Base.metadata.tables:
        return False
    return alembic_helpers.include_object(obj, name, type_, reflected, compare_to)


def run_migrations() -> None:
    options = dict(target_metadata=Base.metadata, include_object=include_object,
                   process_revision_directives=alembic_helpers.writer,
                   render_item=alembic_helpers.render_item)
    if context.is_offline_mode():
        context.configure(url=settings.database_url, literal_binds=True, **options)
        with context.begin_transaction():
            context.run_migrations()
        return
    with create_engine(settings.database_url).connect() as connection:
        context.configure(connection=connection, **options)
        with context.begin_transaction():
            context.run_migrations()


run_migrations()
