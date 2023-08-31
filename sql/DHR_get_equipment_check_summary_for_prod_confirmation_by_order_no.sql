USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_get_equipment_check_summary_for_prod_confirmation_by_order_no]    Script Date: 31/8/2023 5:06:01 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Yadong Zhu
-- Create date: 21 Aug 2023
-- Description:	get equipment check summary data for production/QC confirmation DHR template
-- =============================================
ALTER PROCEDURE [dbo].[DHR_get_equipment_check_summary_for_prod_confirmation_by_order_no]
	@route_sheet_tmpl_family varchar(100), -- DHR Production Route Sheet
	@order_no varchar(40)
AS
BEGIN
select 
process_id,process_revn,
'/#/my-open-processes/view-detail/'+[process_id]+'/'+cast([process_revn] as varchar) as process_url,
ISNULL([Original Initiator],[By]) as [Original Initiator],
COALESCE([Original Completion Date],[close_on]) as [Original Completion Date], 
ISNULL([Selected Line Verification Approver],[Verified By]) as [Verified By],
COALESCE([Line Verification On],[Verified on]) as 	[Verified on],
[station],[shift],cast([sequence] as int) [sequence],table_id,row_index,
[Equipment Name],
[Equipment ID],
[Calibration Due Date],
[Maintenance Due Date],
[Parameter Description],
[Parameter Value],
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
			
			(select value from [BsWebService].[dbo].bpm_process_detail where process_matrix_id=d.process_matrix_id and label='Station Hidden') as station,
			(select value from [BsWebService].[dbo].bpm_process_detail where process_matrix_id=d.process_matrix_id and label='Please Select Shift') as [shift],
			(select value from [BsWebService].[dbo].bpm_process_detail where process_matrix_id=d.process_matrix_id and label='route sheet sequence') as [sequence],
			tc.parent_process_detail_id as table_id,
			tc.row_index,
			tc.label, tc.value from [BsWebService].[dbo].[bpm_process_table_cell] tc
			inner join [BsWebService].[dbo].bpm_process_detail d on 
				tc.parent_process_detail_id=d.id
				inner join [BsWebService].[dbo].bpm_process_matrix m on d.process_matrix_id=m.id 
				inner join [BsWebService].[dbo].bpm_process p on m.process_id=p.id and m.process_revn=p.revn and p.status='close'
				inner join [BsWebService].[dbo].bpm_process_template t on t.id=p.process_template_id
				--inner join [BsWebService].[dbo].[func_get_all_employees](DEFAULT) e on e.user_id=p.initiate_by
				and t.name like @route_sheet_tmpl_family+'%'
				--and t.name like 'DHR Production Route Sheet%'
				and 
				d.process_matrix_id in(
					select process_matrix_id 
					from [BsWebService].[dbo].bpm_process_detail 
					where label='Order No' and value=@order_no 
					--where label='Order No' and value='210000196742'
				) 
				and	
				d.label='Equipment Check'
		) tableResult 
		PIVOT (
			MAX(value) 
			for label in (
				[Equipment Name],
				[Equipment ID],
				[Calibration Due Date],
				[Maintenance Due Date],
				[Parameter Description],
				[Parameter Value],
				[Remark]
			)
		)
		as pivotTable
		order by [Original Completion Date],[Parameter Description],[Equipment Name],[station]
END
