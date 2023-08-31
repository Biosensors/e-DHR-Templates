USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_attachment_by_matrix]    Script Date: 31/8/2023 5:00:39 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 14 August 2022
-- Description:	this sp will find all attachments for the current matrix
-- @attachment_list_name could be
-- 1. Initiator Attachment List
-- 2. Station Operator Attachment List
-- 3. Line Verification Attachment List
-- 3. Team Lead Approval Attachment List
-- 4. QA Approval Attachment List
-- 5. Material Issuance Attachment List

-- =============================================
ALTER PROCEDURE [dbo].[DHR_attachment_by_matrix]
	-- Add the parameters for the stored procedure here
    @process_id varchar(40), -- existing process ID -- for "Amend existing"
    @matrix_label varchar(100), -- initiator,station operator,line verification approval or qa approval
    @attachment_list_name varchar(100), -- initiator,station operator,line verification approval or qa approval
	@is_amend_existing varchar(10) = NULL
AS
BEGIN
	Declare @matrix_id varchar(40);
	Declare @attachment_list_table_id varchar(40);

	--find matrix_id, attachment_list_table_id (if exists) by matrix_label and attachment list name

	select 
		@matrix_id=m.id, 
		@attachment_list_table_id=
		   (select d.id 
			from [BsWebService].[dbo].[bpm_process_detail] d with (nolock)
			where d.label=@attachment_list_name 
				and d.process_matrix_id=m.id)
	from [BsWebService].[dbo].[bpm_process_matrix] m with (nolock)
		inner join [BsWebService].[dbo].[bpm_user_template] ut with (nolock) on ut.id=m.user_template_id 
			and (ut.label=@matrix_label or ut.type=@matrix_label 
			--'Line Verification Approval Attachment List' is in initiator matrix
			--or (ut.type='initiator' and @attachment_list_name='Line Verification Approval Attachment List') 
			)
		inner join [BsWebService].[dbo].[bpm_process] p with (nolock) on m.process_id=p.id and m.process_revn=p.revn 
				and p.id=@process_id and p.status='close';

	--find attachments from the attachment list table + the matrix attachments
	select * from (
				select tc.row_index,tc.label, tc.value,
					e.first_name+' '+e.last_name as [Upload By],
					m.action_on as [Upload On]
				from [BsWebService].[dbo].[bpm_process_table_cell] tc with (nolock)
				inner join [BsWebService].[dbo].[bpm_process_detail] d with (nolock) on 
					tc.parent_process_detail_id=d.id and 
					d.id=@attachment_list_table_id
				inner join [BsWebService].[dbo].[bpm_process_matrix] m with (nolock) on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e on e.user_id=m.user_id	
			) tableResult 
			PIVOT (
				MAX(value) 
				for label in (
					[Attachment Name],
					[Attachment URL]
				)
			)
			as pivotTable
	UNION ALL 
	select 
		0 as row_index, 
		e.first_name+' '+e.last_name as [Upload By],
		m.action_on as [Upload On],		
		a.file_path as [Attachment Name],
		'/download/'+a.process_matrix_id+'/'+a.file_path as [Attachment URL] 
	from [BsWebService].[dbo].[bpm_process_attachement] a with (nolock)
		inner join [BsWebService].[dbo].[bpm_process_matrix] m with (nolock) on a.process_matrix_id=m.id and m.id=@matrix_id
		inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e on e.user_id=m.user_id	
END





