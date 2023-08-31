USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_get_qc_test_items_detail_by_order_no]    Script Date: 31/8/2023 5:06:43 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[DHR_get_qc_test_items_detail_by_order_no] 
	-- Add the parameters for the stored procedure here
	@order_no varchar(40)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
select  process_id,process_revn,
'/#/my-open-processes/view-detail/'+[process_id]+'/'+cast([process_revn] as varchar) as process_url,
[Shift],
[route sheet sequence],
ISNULL([Original Initiator],[By]) as [Original Initiator],
COALESCE([Original Completion Date],[close_on]) as [Original Completion Date], 
ISNULL([Selected Line Verification Approver],[Verified By]) as [Verified By],
COALESCE([Line Verification On],[Verified on]) as 	[Verified on],
[Test Item],
[Qty], 
[Destructive],
[Destructive Qty],
[Pass/Fail],
[Remark]
	   from (
	    select  p.id as process_id,p.revn as process_revn,p.close_on,
		(select top 1 d1.value 
			from [BsWebService].[dbo].bpm_process_detail d1
			inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id and m.type='initiator' and d1.label='Original Initiator'
		) as [Original Initiator],
		(select top 1 d1.value 
			from [BsWebService].[dbo].bpm_process_detail d1
			inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id and m.type='initiator' and d1.label='Original Completion Date'
		) as [Original Completion Date],

		(select top 1 d1.value 
			from [BsWebService].[dbo].bpm_process_detail d1
			inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id and m.type='initiator' and d1.label='Selected Line Verification Approver'
		) as [Selected Line Verification Approver],

		(select top 1 d1.value 
			from [BsWebService].[dbo].bpm_process_detail d1
			inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id and m.type='initiator' and d1.label='Line Verification On'
		) as [Line Verification On],

		(select top 1 d1.value 
			from [BsWebService].[dbo].bpm_process_detail d1
			inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id and m.type='initiator' and d1.label='Shift'
		) as [Shift],
		(select top 1 d1.value 
			from [BsWebService].[dbo].bpm_process_detail d1
			inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id and m.type='initiator' and d1.label='route sheet sequence'
		) as [route sheet sequence],
		(select top 1  e.first_name+' '+e.last_name+' ('+e.user_id+')' 
			from [BsWebService].[dbo].bpm_process_matrix m1 
			inner join [BsWebService].[dbo].bpm_process p1 
			on m1.process_id=p1.id and m1.process_revn=p1.revn and p1.id=p.id and p1.revn=p.revn and m1.type='initiator' and p1.status='close'
		    inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e on m1.user_id=e.user_id
		) as [By],
		(select top 1  m.action_on
			from [BsWebService].[dbo].bpm_process_matrix m1 
			inner join [BsWebService].[dbo].bpm_process p1 
			on m1.process_id=p1.id and m1.process_revn=p1.revn and p1.id=p.id and p1.revn=p.revn and m1.type='initiator' and p1.status='close'
		) as [Update on],
		(select top 1  e.first_name+' '+e.last_name+' ('+e.user_id+')' 
			from [BsWebService].[dbo].bpm_process_matrix m1 
			inner join [BsWebService].[dbo].bpm_process p1 
			on m1.process_id=p1.id and m1.process_revn=p1.revn and p1.id=p.id and p1.revn=p.revn and m1.type='approver' and p1.status='close'
		    inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e on m1.user_id=e.user_id
		) as [Verified By],
		(select top 1  m1.action_on
			from [BsWebService].[dbo].bpm_process_matrix m1 
			inner join [BsWebService].[dbo].bpm_process p1 
			on m1.process_id=p1.id and m1.process_revn=p1.revn and p1.id=p.id and p1.revn=p.revn and m1.type='approver' and p1.status='close'
		) as [Verified On],
            tc.label,tc.value,tc.row_index+1 as [line]			
			from [BsWebService].[dbo].bpm_process_table_cell tc 
				inner join [BsWebService].[dbo].bpm_process_detail d on tc.parent_process_detail_id=d.id
				inner join [BsWebService].[dbo].bpm_process_matrix m on d.process_matrix_id=m.id
				inner join [BsWebService].[dbo].bpm_process p on m.process_id=p.id and m.process_revn=p.revn and p.status='close' 
				inner join [BsWebService].[dbo].bpm_process_template t on p.process_template_id=t.id  
				and t.name like 'DHR QC Inspection Route Sheet%'
				and  d.process_matrix_id in(
					select d1.process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail d1
					inner join [BsWebService].[dbo].bpm_process_matrix m1 on d1.process_matrix_id=m.id and m.id=m1.id
					inner join [BsWebService].[dbo].bpm_process p1 on p1.id=p.id and m1.process_id=p1.id and m1.process_revn=p1.revn
					where label='Order No' and value=@order_no
					 --where label='Order No' and value='210000196801'
				) 
               and d.label='Test Items'
			) detailResult  
		PIVOT ( 
			MAX(value)  
			for label in (
				[Test Item],
				[Qty], 
				[Destructive],
				[Destructive Qty],
				[Pass/Fail],
				[Remark]
			) 
		) as route_sheet_table 
		order by [route sheet sequence]
END
