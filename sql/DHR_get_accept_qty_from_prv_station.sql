USE [BpmTemplate]
GO
/****** Object:  StoredProcedure [dbo].[DHR_get_accept_qty_from_prv_station]    Script Date: 31/8/2023 5:05:00 pm ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ya Dong Zhu
-- Create date: 03 May 2023
-- Description:	this SP is used in Production Route Sheet template, and will find :
-- 1. the accept qty from previous station
-- 2. if the current station is the first one (starts with '1 -'), return plan_qty

-- =============================================
ALTER PROCEDURE [dbo].[DHR_get_accept_qty_from_prv_station]
	-- Add the parameters for the stored procedure here
    @production_line nvarchar(200),
    @sub_group nvarchar(200),
    @order_no varchar(40), -- production order no -- for "Create New"
    @current_station nvarchar(200), -- current station
    @plan_qty varchar(10) -- plan qty from material issurance
AS

BEGIN
    IF (SUBSTRING(@current_station,1,3)='1 -')
        select	NULL as [Previous Station],	@plan_qty as [Accept Qty]
    ELSE
        BEGIN
            DECLARE @prev_station NVARCHAR(100)
            select  @prev_station=previous_station from (
            select a.prod_station as current_station,LAG(a.prod_station) OVER (ORDER BY a.prod_station) as previous_station from (
                SELECT CAST(ROW_NUMBER() OVER(ORDER BY [Process Station No] ASC) AS VARCHAR) +' - ' +[Process Station Description] as prod_station
                FROM [BpmTemplate].[dbo].[DHR_process_stations_mgt]
                where 
                [Production Line]=@production_line and
                --[Production Line]='SMS' and
                CHARINDEX([Applicable Sub-Group],@sub_group+',All')>0
                --CHARINDEX([Applicable Sub-Group],'CoCr,All')>0
                ) a
            ) b
            where current_station=@current_station
            --where current_station='2 - Parafilm And Stent Crimping (WI-10784)'

            select	[Station] as [Previous Station],
                    SUM(cast([Accept Qty] as int)) as [Accept Qty]
                    from (
                        select 
                        p.id as last_process_id,p.revn as last_process_revn, 
                        d.label, d.value			
                        from [BsWebService].[dbo].bpm_process_detail d 
                            inner join [BsWebService].[dbo].bpm_process_matrix m on d.process_matrix_id=m.id 
                            inner join [BsWebService].[dbo].bpm_process p on m.process_id=p.id and m.process_revn=p.revn and p.status='close'
                            inner join [BsWebService].[dbo].bpm_process_template t on t.id=p.process_template_id
                            and t.name like 'DHR Production Route Sheet%'
                            and d.process_matrix_id in(
                                select process_matrix_id 
                                from [BsWebService].[dbo].bpm_process_detail 
                                where label='Work Order No' and value=@order_no
                                --where label='Work Order No' and value='210000196576'
                            ) 
                        ) detailResult  
                    PIVOT ( 
                        MAX(value)  
                        for label in (
                            [Station],
                            [Accept Qty]
                        ) 
                    )  pivot_table 
                    where [Station]=@prev_station
                    group by [Station]
        END
END
