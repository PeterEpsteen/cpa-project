﻿CREATE procedure search_type2
	@ratioID int, @companyID int

as
begin

declare @name varchar(60)
declare @maxdepth int
declare @perms table (term varchar(max))
declare @match table (type int, name varchar(max))
declare @terms table (id int not null identity(1,1), term varchar(30))
declare @articles table (id int, source nvarchar(max), [date] date, url nvarchar(max), text nvarchar(max), title nvarchar(max))

declare term_cursor cursor for
select lower(name) from ratio_construct
where id in (
	select rc.id from ratio_construct rc
	join ratio_detail rd on rc.id = rd.ratio_construct_id
	where rd.ratio_id = @ratioID
)

open term_cursor
fetch next from term_cursor into @name

while @@FETCH_STATUS = 0
begin
	insert into @terms
	select value from string_split(@name, ' ') 
	where value not in (select word from common_words)

	select @maxdepth = max(id) from @terms

	insert into @perms
	select term from @terms

	if @maxdepth >=2 
		begin
			insert into @perms
			select concat(a.term, ' ', b.term)
			from @terms b, @terms a
			where a.id <> b.id
		end

	if @maxdepth >=3 
		begin
			insert into @perms
			select concat(a.term, ' ', b.term, ' ', c.term)
			from @terms b, @terms a, @terms c
			where b.term <> a.term and
				b.id <> c.id and
				a.id <> c.id
		end

	if @maxdepth >=4 
		begin
			insert into @perms
			select concat(a.term, ' ', b.term, ' ', c.term, ' ', d.term)
			from @terms b, @terms a, @terms d, @terms c
			where a.id <> b.id and
				b.id <> c.id and
				a.id <> c.id and
				c.id <> d.id and
				b.id <> d.id and
				a.id <> d.id
		end

	insert into @match
	select distinct type, concat('"', name, '"') as [name]
	from object
	inner join @perms p on object.name like p.term
	and name not in (select name from @match)
	
	delete from @terms

	fetch next from term_cursor into @name
end

close term_cursor
deallocate term_cursor

declare name_cursor cursor for
select distinct name from @match

open name_cursor
fetch next from name_cursor into @name

while @@FETCH_STATUS = 0
begin
	insert into @articles
	select id, source, [date], url, text, title
	from article
	where contains ((text, title), @name) and
		company_id = @companyID and
		id not in (select id from @articles)

	fetch next from name_cursor into @name
end

close name_cursor
deallocate name_cursor

select * from @articles

end
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[search_type2] TO [IIS APPPOOL\DefaultAppPool]
    AS [dbo];

