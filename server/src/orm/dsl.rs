use diesel::{
    query_builder::{AstPass, Query, QueryFragment},
    sql_types::Integer,
    sqlite::Sqlite,
    QueryDsl, QueryId, QueryResult, RunQueryDsl, SqliteConnection,
};

#[derive(Debug, Clone, Copy, QueryId)]
pub struct Randomized<T> {
    query: T,
    limit: i32,
}

impl<T> QueryFragment<Sqlite> for Randomized<T>
where
    T: QueryFragment<Sqlite>,
{
    fn walk_ast<'b>(&'b self, mut out: AstPass<'_, 'b, Sqlite>) -> QueryResult<()> {
        self.query.walk_ast(out.reborrow())?;
        out.push_sql(" ORDER BY RANDOM() LIMIT ");
        out.push_bind_param::<Integer, _>(&self.limit)?;
        Ok(())
    }
}

impl<T: Query> Query for Randomized<T> {
    type SqlType = T::SqlType;
}

impl<T> QueryDsl for Randomized<T> {}
impl<T> RunQueryDsl<SqliteConnection> for Randomized<T> {}

pub trait RandomDsl: Sized {
    fn randomize(self, count: i32) -> Randomized<Self>;
}

impl<T> RandomDsl for T {
    fn randomize(self, count: i32) -> Randomized<Self> {
        Randomized {
            query: self,
            limit: count,
        }
    }
}
