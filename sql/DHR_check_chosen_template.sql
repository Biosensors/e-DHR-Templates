USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_check_chosen_template]    Script Date: 31/8/2023 5:04:11 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 21st July 2022
-- Description:	this is SP for checking if user is using a correct template revision 
--	1. Related templates: Material Issuing, Prod Route sheet, Prod confirmation, QC route sheet, QC Confirmation, Routesheet consolidation
--  2. Logic: 
--		a.check if the Order No is using in any of revisions (either previuos or latest), return a query revision
--			i. if No, 
--				i) throw errors if the @chosen_tmpl_name is not latest revision, return latest revision
--				ii) NO error if @chosen_tmpl_name is latest revision, No return value

--			ii. if Yes, 
--				i) throw errors if the query revision is not same as @chosen_tmpl_name, return correct revision
--				ii) NO error if @chosen_tmpl_name is query revision, no return value
--	3. Return: the SP will returns the following result when the wrong template is chosen,
-- 		a. [correct_template_id]|[correct_template_name] as correct_template
--		c. message: "wrong template"
--	4. Return: the SP will returns the following result when correct template is chosen,
-- 		a. order_no
--		b. message: "correct template"
--
-- =============================================
ALTER PROCEDURE [dbo].[DHR_check_chosen_template]
	-- Add the parameters for the stored procedure here
	-- template name should follow this naming convention: (case sensitive)
	-- Production Material Issuance - Rev.xx (e.g. Rev.01,Rev.02, etc)
	-- Production Route Sheet - Rev.01 (e.g. Rev.01,Rev.02, etc)
	-- Production Confirmation - Rev.01 (e.g. Rev.01,Rev.02, etc)
	-- QC Inspection Route Sheet - Rev.01 (e.g. Rev.01,Rev.02, etc)
	-- QC Confirmation - Rev.01 (e.g. Rev.01,Rev.02, etc)
	-- QC Confirmation - Rev.01 (e.g. Rev.01,Rev.02, etc)
 
    @chosen_tmpl_name nvarchar(100), 
	-- @selected_order  is in format of 'Order:210000162552, Material:10166-006, Batch No:W21110479'
    @selected_order nvarchar(100) 
AS
BEGIN

	DECLARE @order_no NVARCHAR(40);
	DECLARE @template_family NVARCHAR(100); -- like 'Production Material Issuance - Rev'
	DECLARE @template_revision NVARCHAR(5); -- like '01'
	DECLARE @latest_template_name NVARCHAR(100); -- like 'Production Material Issuance - Rev.01'
	DECLARE @latest_template_id NVARCHAR(100); -- like 'Production Material Issuance - Rev.01'
	DECLARE @correct_template_name NVARCHAR(100); -- like 'Production Material Issuance - Rev.01'
	DECLARE @correct_template_id NVARCHAR(100); -- 

	SELECT 
		@template_family = IIF(rownum = 1, [value], @template_family),
		@template_revision = IIF(rownum = 2, [value], @template_revision)
	FROM (
		SELECT [value],ROW_NUMBER() OVER(ORDER BY value desc) as rownum 
		FROM STRING_SPLIT(@chosen_tmpl_name,'.') 
	) a

    IF CHARINDEX('Order',@selected_order)>=1
    BEGIN
        DECLARE @temp nvarchar(100); -- e.g. Order:210000162552
        SELECT top 1 @temp=[value] FROM STRING_SPLIT(@selected_order,',') 
        SELECT top 1 @order_no=SUBSTRING(@temp,7,20);
    END
    ELSE
        SET @order_no=@selected_order;

	-- find latest revision
	SELECT top 1 @latest_template_name=[name],@latest_template_id=id
	FROM  [BsWebService].[dbo].[bpm_process_template] with (nolock)
	WHERE [name] like @template_family+'%'
	ORDER BY [name] DESC

	-- query if any of revsions is using the Order NO
	select @correct_template_id=t.id,@correct_template_name=t.name
		from [BsWebService].[dbo].[bpm_process_detail] d with (nolock)
		inner join [BsWebService].[dbo].[bpm_process_matrix] m with (nolock) on d.process_matrix_id=m.id and m.type='initiator' and d.label='Order No' and d.value=@order_no
		inner join [BsWebService].[dbo].[bpm_process] p with (nolock) on m.process_id=p.id and m.process_revn=p.revn
		inner join [BsWebService].[dbo].[bpm_process_template] t with (nolock) on p.process_template_id = t.id and t.name like @template_family+'%'
	
	IF (
			(@correct_template_id IS NULL AND @latest_template_name!=@chosen_tmpl_name) -- if the Order NO is NOT used by any of revisions, and @chosen_tmpl_name is NOT the latest revsion
			OR 
			(@correct_template_id IS NOT NULL AND @correct_template_name!=@chosen_tmpl_name)  --if the Order NO is used a template revision but not  @chosen_tmpl_name 
		)
		SELECT 
			ISNULL(@correct_template_id,@latest_template_id) + '|' +ISNULL(@correct_template_name,@latest_template_name) as correct_template,
			NULL as order_no,
			'wrong template' as message;
	ELSE 
		SELECT NULL as correct_template, @order_no as order_no,'correct template' as message;
END
